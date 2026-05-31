/**
 * DE-007 Phase 1 Spike — pi Extension: SATAN tools over MCP/UDS
 *
 * DEC-12 front-end: node `net` client speaking MCP to dl-satan-mcp's UDS.
 * SATAN-agnostic MCP→pi-tools bridge. Runs untrusted in pi's jail.
 *
 * Emacs-side peer: mcp-smoke.el (proven), later dl-satan-mcp.el (Phase 2).
 *
 * Usage (for spike testing against mcp-smoke.el):
 *   1. In Emacs: (load-file ".../phases/spike/mcp-smoke.el") M-x mcp-smoke-start
 *   2. pi -e phases/spike/satan-extension-spike.ts
 *   3. In pi: try "call satan_smoke_echo with msg hello"
 *
 * Key spike questions this answers:
 *   Q1: Does node net.createConnection(UDS) work in pi's jail?
 *   Q2: Does dynamic pi.registerTool() after tools/list work same-session?
 *   Q3: Runtime JSON Schema → TypeBox conversion feasible?
 *   Q4: Newline-delimited JSON-RPC framing Node↔Emacs?
 *   Q5: Tool execution round-trip within pi's timeout?
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type, type TSchema } from "typebox";
import * as net from "node:net";
import * as fs from "node:fs";

// ─── Configuration ───────────────────────────────────────────────────────────

const SOCKET_PATH =
  process.env.SATAN_MCP_SOCKET ||
  (process.env.XDG_RUNTIME_DIR
    ? `${process.env.XDG_RUNTIME_DIR}/satan-mcp-smoke.sock`
    : "/tmp/satan-mcp-smoke.sock");

const MCP_TIMEOUT_MS = 30_000; // generous for first-tool cold starts
const PROTOCOL_VERSION = "2025-06-18";

// ─── MCP Transport (newline-delimited JSON-RPC 2.0 over UDS) ─────────────────

type JsonRpcRequest = {
  jsonrpc: "2.0";
  id: number;
  method: string;
  params?: unknown;
};

type JsonRpcResponse = {
  jsonrpc: "2.0";
  id: number;
  result?: unknown;
  error?: { code: number; message: string };
};

/** Minimal MCP-over-UDS client. Single-request (no concurrent multiplexing). */
class McpClient {
  #sock: net.Socket | null = null;
  #buffer = "";
  #nextId = 1;
  #pending: Map<
    number,
    { resolve: (v: unknown) => void; reject: (e: Error) => void }
  > = new Map();

  async connect(path: string): Promise<void> {
    if (this.#sock) throw new Error("Already connected");

    return new Promise((resolve, reject) => {
      const s = net.createConnection(path);

      s.on("connect", () => {
        this.#sock = s;
        resolve();
      });

      s.on("error", (err: NodeJS.ErrnoException) => {
        reject(
          new Error(
            `MCP socket connect failed (${err.code ?? "unknown"}): ${err.message}`,
          ),
        );
      });

      s.on("data", (chunk: Buffer) => {
        this.#buffer += chunk.toString();
        const lines = this.#buffer.split("\n");
        this.#buffer = lines.pop() ?? ""; // trailing partial stays in buffer
        for (const line of lines) {
          const trimmed = line.trim();
          if (!trimmed) continue;
          try {
            const msg: JsonRpcResponse = JSON.parse(trimmed);
            this.#dispatch(msg);
          } catch {
            // malformed line → ignore (protocol error handled by caller's timeout)
          }
        }
      });

      s.on("close", () => {
        this.#sock = null;
        // Reject all pending to unblock any waiting tool calls
        for (const [, h] of this.#pending) {
          h.reject(new Error("MCP connection closed"));
        }
        this.#pending.clear();
      });
    });
  }

  disconnect(): void {
    if (this.#sock) {
      this.#sock.destroy();
      this.#sock = null;
    }
  }

  isConnected(): boolean {
    return this.#sock !== null && !this.#sock.destroyed;
  }

  async request(method: string, params?: unknown): Promise<unknown> {
    if (!this.#sock || this.#sock.destroyed) {
      throw new Error("MCP not connected");
    }

    const id = this.#nextId++;
    const req: JsonRpcRequest = { jsonrpc: "2.0", id, method };
    if (params !== undefined) req.params = params;

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.#pending.delete(id);
        reject(new Error(`MCP timeout: ${method}`));
      }, MCP_TIMEOUT_MS);

      this.#pending.set(id, {
        resolve: (v) => {
          clearTimeout(timer);
          resolve(v);
        },
        reject: (e) => {
          clearTimeout(timer);
          reject(e);
        },
      });

      this.#sock!.write(JSON.stringify(req) + "\n");
    });
  }

  /** Send a notification (no response expected). */
  notify(method: string, params?: unknown): void {
    if (!this.#sock || this.#sock.destroyed) return;
    const msg = { jsonrpc: "2.0", method, ...(params ? { params } : {}) };
    this.#sock.write(JSON.stringify(msg) + "\n");
  }

  #dispatch(msg: JsonRpcResponse): void {
    if (msg.id === undefined || msg.id === null) return; // notification or malformed
    const handler = this.#pending.get(msg.id);
    if (!handler) return;
    this.#pending.delete(msg.id);

    if (msg.error) {
      handler.reject(
        new Error(`MCP error ${msg.error.code}: ${msg.error.message}`),
      );
    } else {
      handler.resolve(msg.result);
    }
  }
}

// ─── JSON Schema → TypeBox runtime converter ─────────────────────────────────
//
// SATAN tool :args-schema uses only: string, integer, boolean, number, object
// (with nested properties), array (with items), enum (on string), pattern.
// No $ref / allOf / anyOf / oneOf.

interface McpInputSchema {
  type: string;
  properties?: Record<string, McpInputSchema>;
  required?: string[];
  enum?: (string | number)[];
  items?: McpInputSchema;
  pattern?: string;
}

function jsonSchemaToTypeBox(schema: McpInputSchema): TSchema {
  switch (schema.type) {
    case "string": {
      if (schema.enum && schema.enum.length > 0) {
        // Type.Union of Type.Literal for each enum value
        const literals = schema.enum.map((v) =>
          Type.Literal(v as string),
        ) as unknown as [TSchema, ...TSchema[]];
        return Type.Union(literals);
      }
      const opts: Record<string, unknown> = {};
      if (schema.pattern) opts.pattern = schema.pattern;
      return Type.String(opts);
    }
    case "integer":
      return Type.Integer();
    case "number":
      return Type.Number();
    case "boolean":
      return Type.Boolean();
    case "object": {
      if (!schema.properties) return Type.Any(); // free-form object (shouldn't happen in SATAN)
      const shape: Record<string, TSchema> = {};
      const required = new Set(schema.required ?? []);
      for (const [key, propSchema] of Object.entries(schema.properties)) {
        const prop = jsonSchemaToTypeBox(propSchema);
        shape[key] = required.has(key) ? prop : Type.Optional(prop);
      }
      return Type.Object(shape);
    }
    case "array": {
      if (!schema.items) return Type.Array(Type.Any());
      return Type.Array(jsonSchemaToTypeBox(schema.items));
    }
    default:
      return Type.Any();
  }
}

// ─── MCP Tool shape (from tools/list response) ───────────────────────────────

interface McpTool {
  name: string;
  description?: string;
  inputSchema?: McpInputSchema;
}

interface McpInitializeResult {
  protocolVersion: string;
  capabilities: Record<string, unknown>;
  serverInfo: { name: string; version: string };
}

interface McpCallResult {
  content: Array<{ type: string; text?: string }>;
  isError?: boolean;
}

// ─── Extension ───────────────────────────────────────────────────────────────

export default async function satanMcpExtension(pi: ExtensionAPI) {
  const client = new McpClient();

  // ── Lifecycle ──────────────────────────────────────────────────────────

  pi.on("session_start", async (_event, ctx) => {
    try {
      // Check socket exists before connecting (better error message)
      if (!fs.existsSync(SOCKET_PATH)) {
        ctx.ui.notify(
          `SATAN MCP: socket not found at ${SOCKET_PATH} — is dl-satan-mcp running?`,
          "warning",
        );
        return;
      }

      await client.connect(SOCKET_PATH);
      ctx.ui.notify(`SATAN MCP: connected to ${SOCKET_PATH}`, "info");

      // MCP handshake
      const initResult = (await client.request("initialize", {
        protocolVersion: PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: { name: "satan-pi-extension", version: "0.1.0" },
      })) as McpInitializeResult;

      client.notify("notifications/initialized");
      ctx.ui.notify(
        `SATAN MCP: initialized (server: ${initResult.serverInfo.name} ${initResult.serverInfo.version})`,
        "info",
      );

      // Discover & register tools
      const toolsResult = (await client.request("tools/list")) as {
        tools: McpTool[];
      };

      for (const tool of toolsResult.tools) {
        try {
          const schema = tool.inputSchema
            ? jsonSchemaToTypeBox(tool.inputSchema)
            : Type.Any();

          pi.registerTool({
            name: tool.name,
            label: tool.name,
            description: tool.description ?? `SATAN tool: ${tool.name}`,
            parameters: schema,
            async execute(toolCallId, params, signal, _onUpdate, _ctx) {
              if (signal?.aborted) {
                return {
                  content: [{ type: "text", text: "Tool call aborted" }],
                  isError: true,
                  details: {},
                };
              }

              const result = (await client.request("tools/call", {
                name: tool.name,
                arguments: params,
              })) as McpCallResult;

              return {
                content: result.content,
                details: {},
                ...(result.isError ? { isError: true } : {}),
              };
            },
          });

          ctx.ui.notify(
            `SATAN MCP: registered tool "${tool.name}"`,
            "info",
          );
        } catch (err) {
          ctx.ui.notify(
            `SATAN MCP: failed to register tool "${tool.name}": ${err}`,
            "error",
          );
        }
      }

      ctx.ui.notify(
        `SATAN MCP: ${toolsResult.tools.length} tools registered`,
        "info",
      );
    } catch (err) {
      ctx.ui.notify(
        `SATAN MCP: connection failed — ${err}`,
        "error",
      );
    }
  });

  pi.on("session_shutdown", async () => {
    client.disconnect();
  });

  // ── Ping command for diagnostics ───────────────────────────────────────

  pi.registerCommand("satan-ping", {
    description: "Ping the SATAN MCP server",
    handler: async (_args, ctx) => {
      if (!client.isConnected()) {
        ctx.ui.notify("SATAN MCP: not connected", "warning");
        return;
      }
      try {
        await client.request("ping");
        ctx.ui.notify("SATAN MCP: pong!", "info");
      } catch (err) {
        ctx.ui.notify(`SATAN MCP: ping failed — ${err}`, "error");
      }
    },
  });
}
