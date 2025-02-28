#!/usr/bin/env node

/**
 * PostgreSQL MCP Server
 * 
 * This server provides a Model Context Protocol interface to PostgreSQL databases,
 * allowing LLMs to execute read-only queries and explore database schemas.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import pg from "pg";
import dotenv from "dotenv";

/*
 * IMPORTANT: MCP Integration Rule
 * ------------------------------
 * When adding new functionality to this server:
 * 1. Update the README.md file with the new endpoint details
 * 2. Include the endpoint in the "Instructing Claude" section
 * 3. Follow the existing format:
 *    ```http
 *    METHOD /endpoint
 *    ```
 *    Description and any required request body/parameters
 *
 * This ensures Claude can be properly instructed about all available functionality.
 */

// Load environment variables early
dotenv.config();

// Configuration constants
const DEBUG = process.env.DEBUG === "true";
const API_TIMEOUT_MS = 30000; // 30 second timeout for API calls
const HEARTBEAT_INTERVAL_MS = 5000; // 5 second heartbeat interval
const MAX_RECONNECT_ATTEMPTS = 5;
const RECONNECT_DELAY_MS = 1000;

// Connection state tracking
const connectionState = {
  isConnected: false,
  reconnectAttempts: 0,
  lastHeartbeat: Date.now(),
  isShuttingDown: false,
};

// Utility functions
function debugLog(...args: any[]) {
  if (DEBUG) {
    console.error(`[DEBUG][${new Date().toISOString()}]`, ...args);
  }
}

function handleError(error: any, context: string) {
  const timestamp = new Date().toISOString();
  console.error(`[ERROR][${timestamp}] ${context}:`, error);
  if (error?.response?.data) {
    console.error("API Response:", error.response.data);
  }
  // Log stack trace for unexpected errors
  if (error instanceof Error) {
    console.error("Stack trace:", error.stack);
  }
}

// Utility to create a timeout promise
function createTimeout(ms: number, message: string) {
  return new Promise((_, reject) =>
    setTimeout(() => reject(new Error(`Timeout after ${ms}ms: ${message}`)), ms)
  );
}

// Utility to wrap promises with timeout
async function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  context: string
): Promise<T> {
  try {
    return await Promise.race([
      promise,
      createTimeout(timeoutMs, context),
    ]) as T;
  } catch (error: any) {
    if (error?.message?.includes("Timeout after")) {
      debugLog(`Operation timed out: ${context}`);
    }
    throw error;
  }
}

debugLog("Environment variables loaded");

// Get database URL from environment variable or command line arguments
let databaseUrl: string;

// First check if DATABASE_URL environment variable is set
if (process.env.DATABASE_URL) {
  databaseUrl = process.env.DATABASE_URL;
  debugLog("Using DATABASE_URL from environment variable");
} else {
  // Fall back to command line arguments
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error("Please provide a database URL as a command-line argument or set DATABASE_URL environment variable");
    process.exit(1);
  }
  databaseUrl = args[0];
  debugLog("Using database URL from command line argument");
}

// Create a pool for database connections
const pool = new pg.Pool({
  connectionString: databaseUrl,
  max: 20, // Maximum number of clients in the pool
  idleTimeoutMillis: 30000, // How long a client is allowed to remain idle before being closed
  connectionTimeoutMillis: 5000, // How long to wait for a connection to become available
});

// Add event listeners to the pool for better error handling
pool.on('error', (err: Error) => {
  handleError(err, "Unexpected error on idle client");
});

// Create the MCP server with explicit capabilities
const server = new McpServer({
  name: "postgres-mcp-server",
  version: "1.0.0",
  capabilities: {
    tools: {
      postgres_query: {
        description: "Run a read-only SQL query against the PostgreSQL database",
        parameters: {
          sql: { type: "string", description: "SQL query to execute (read-only)" },
        },
        required: ["sql"],
      },
      postgres_list_tables: {
        description: "List all tables in the PostgreSQL database",
        parameters: {},
      },
      postgres_describe_table: {
        description: "Get the schema of a specific table in the PostgreSQL database",
        parameters: {
          tableName: { type: "string", description: "Name of the table to describe" },
        },
        required: ["tableName"],
      },
    },
  },
});

debugLog("MCP server created");

// Helper function for database operations with proper error handling
async function executeDbQuery<T>(
  queryFn: (client: pg.PoolClient) => Promise<T>,
  errorContext: string
): Promise<T> {
  const client = await pool.connect();
  try {
    return await queryFn(client);
  } catch (error) {
    handleError(error, errorContext);
    throw error;
  } finally {
    client.release();
  }
}

// Add PostgreSQL tools with improved error handling
server.tool(
  "postgres_query",
  {
    sql: z.string().describe("SQL query to execute (read-only)"),
  },
  async (params: { sql: string }) => {
    try {
      debugLog("Executing SQL query:", params.sql);
      
      return await executeDbQuery(async (client) => {
        await client.query("BEGIN TRANSACTION READ ONLY");
        try {
          const result = await withTimeout(
            client.query(params.sql),
            API_TIMEOUT_MS,
            "Executing SQL query"
          ) as pg.QueryResult;
          
          debugLog(`Query executed successfully, returned ${result.rows.length} rows`);
          
          return {
            content: [
              {
                type: "text",
                text: JSON.stringify(result.rows, null, 2),
              },
            ],
          };
        } finally {
          client
            .query("ROLLBACK")
            .catch((error: Error) => console.warn("Could not roll back transaction:", error));
        }
      }, "Failed to execute SQL query");
    } catch (error) {
      handleError(error, "Failed to execute SQL query");
      throw error;
    }
  }
);

server.tool(
  "postgres_list_tables",
  {},
  async () => {
    try {
      debugLog("Listing database tables");
      
      return await executeDbQuery(async (client) => {
        const result = await withTimeout(
          client.query(
            "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'"
          ),
          API_TIMEOUT_MS,
          "Listing database tables"
        ) as pg.QueryResult;
        
        debugLog(`Found ${result.rows.length} tables`);
        
        const tableList = result.rows.map((row: { table_name: string }) => row.table_name);
        
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(tableList, null, 2),
            },
          ],
        };
      }, "Failed to list database tables");
    } catch (error) {
      handleError(error, "Failed to list database tables");
      throw error;
    }
  }
);

server.tool(
  "postgres_describe_table",
  {
    tableName: z.string().describe("Name of the table to describe"),
  },
  async (params: { tableName: string }) => {
    try {
      debugLog("Describing table:", params.tableName);
      
      return await executeDbQuery(async (client) => {
        const result = await withTimeout(
          client.query(
            "SELECT column_name, data_type, is_nullable, column_default FROM information_schema.columns WHERE table_name = $1",
            [params.tableName]
          ),
          API_TIMEOUT_MS,
          `Describing table ${params.tableName}`
        ) as pg.QueryResult;
        
        debugLog(`Table description retrieved with ${result.rows.length} columns`);
        
        if (result.rows.length === 0) {
          return {
            content: [
              {
                type: "text",
                text: `Table '${params.tableName}' not found or has no columns.`,
              },
            ],
          };
        }
        
        return {
          content: [
            {
              type: "text",
              text: JSON.stringify(result.rows, null, 2),
            },
          ],
        };
      }, `Failed to describe table ${params.tableName}`);
    } catch (error) {
      handleError(error, `Failed to describe table ${params.tableName}`);
      throw error;
    }
  }
);

// Handle graceful shutdown
const shutdown = async () => {
  if (connectionState.isShuttingDown) {
    return; // Prevent multiple shutdown attempts
  }
  
  connectionState.isShuttingDown = true;
  debugLog("Shutting down gracefully...");

  // Close database pool
  try {
    await pool.end();
    debugLog("Database pool closed successfully");
  } catch (error) {
    handleError(error, "Database pool closure failed");
  }

  // Close transport
  try {
    await transport.close();
    debugLog("Transport closed successfully");
  } catch (error) {
    handleError(error, "Transport closure failed");
  }

  process.exit(0);
};

// Create and configure transport
const transport = new StdioServerTransport();

// Define message type for better type safety
interface McpMessage {
  method?: string;
  params?: any;
  id?: string | number;
}

transport.onerror = async (error: any) => {
  handleError(error, "Transport error");
  if (connectionState.reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
    connectionState.reconnectAttempts++;
    debugLog(
      `Attempting reconnection (${connectionState.reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})...`
    );
    setTimeout(async () => {
      try {
        await server.connect(transport);
        connectionState.isConnected = true;
        connectionState.reconnectAttempts = 0; // Reset counter on successful reconnection
        debugLog("Reconnection successful");
      } catch (reconnectError) {
        handleError(reconnectError, "Reconnection failed");
        if (connectionState.reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
          debugLog("Max reconnection attempts reached, shutting down");
          await shutdown();
        }
      }
    }, RECONNECT_DELAY_MS);
  } else {
    debugLog("Max reconnection attempts reached, shutting down");
    await shutdown();
  }
};

transport.onmessage = async (message: McpMessage) => {
  try {
    debugLog("Received message:", message?.method);

    if (message?.method === "initialize") {
      debugLog("Handling initialize request");
      connectionState.isConnected = true;
      connectionState.lastHeartbeat = Date.now();
    } else if (message?.method === "initialized") {
      debugLog("Connection fully initialized");
      connectionState.isConnected = true;
    } else if (message?.method === "server/heartbeat") {
      connectionState.lastHeartbeat = Date.now();
      debugLog("Heartbeat received");
    }
  } catch (error) {
    handleError(error, "Message handling error");
    throw error;
  }
};

// Set up heartbeat check
const heartbeatCheck = setInterval(() => {
  if (!connectionState.isConnected) {
    return; // Skip check if not connected
  }
  
  const timeSinceLastHeartbeat = Date.now() - connectionState.lastHeartbeat;
  if (timeSinceLastHeartbeat > HEARTBEAT_INTERVAL_MS * 2) {
    debugLog("No heartbeat received, attempting reconnection");
    if (transport && transport.onerror) {
      transport.onerror(new Error("Heartbeat timeout"));
    }
  }
}, HEARTBEAT_INTERVAL_MS);

// Clear heartbeat check on process exit
process.on("beforeExit", () => {
  clearInterval(heartbeatCheck);
});

// Update signal handlers
process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

// Add global error handlers
process.on("uncaughtException", (error: Error) => {
  handleError(error, "Uncaught Exception");
  shutdown();
});

process.on("unhandledRejection", (reason: any, promise: Promise<any>) => {
  console.error("Unhandled Rejection at:", promise, "reason:", reason);
  shutdown();
});

// Main startup function to coordinate initialization
async function startServer() {
  // Verify database connection before starting server
  try {
    debugLog("Verifying database connection...");
    const client = await pool.connect();
    client.release();
    debugLog("Database connection verified");
  } catch (error) {
    handleError(error, "Failed to verify database connection");
    process.exit(1);
  }

  // Connect to transport with initialization handling
  try {
    debugLog("Connecting to MCP transport...");
    await server.connect(transport);
    debugLog("MCP server connected and ready");
  } catch (error) {
    handleError(error, "Failed to connect MCP server");
    process.exit(1);
  }

  // Keep the process alive and handle errors
  process.stdin.resume();
  process.stdin.on("error", (error: Error) => {
    handleError(error, "stdin error");
  });

  process.stdout.on("error", (error: Error) => {
    handleError(error, "stdout error");
  });
  
  debugLog("Server startup complete");
}

// Start the server
startServer().catch(error => {
  handleError(error, "Unexpected error during server startup");
  process.exit(1);
}); 