---
sidebar_position: 6
---

# API Reference

Complete API reference for all Hikari types and methods, including the new v0.2.0 features like WebSocket support and enhanced route groups.

## App

The main application instance.

### `hikari.New(addr string) *App`

Creates a new Hikari application instance.

```go
app := hikari.New(":8080")
```

### WebSocket Methods (v0.2.0)

#### `WithWebSocket(config *WebSocketConfig) *App`

Enable WebSocket support with optional configuration.

```go
// Use default configuration
app.WithWebSocket(nil)

// Use custom configuration
wsConfig := &hikari.WebSocketConfig{
    ReadBufferSize:    1024,
    WriteBufferSize:   1024,
    HandshakeTimeout:  10 * time.Second,
    CheckOrigin:       func(r *http.Request) bool { return true },
    EnableCompression: true,
    PingInterval:      30 * time.Second,
    PongTimeout:       60 * time.Second,
}
app.WithWebSocket(wsConfig)
```

#### `WebSocket(path, hubName string, handler WebSocketHandler, middleware ...Middleware)`

Register a WebSocket endpoint with hub name and handler.

```go
app.WebSocket("/ws/chat", "chat_room", chatHandler)
app.WebSocket("/ws/private", "private_messages", privateHandler, authMiddleware)
```

#### `GetWebSocketHub(name string) (*WebSocketHub, bool)`

Get a WebSocket hub by name for external access.

```go
if hub, exists := app.GetWebSocketHub("chat_room"); exists {
    hub.Broadcast([]byte("Server announcement"))
}
```

### HTTP Methods

#### `GET(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `POST(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `PUT(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `PATCH(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `DELETE(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `OPTIONS(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `HEAD(pattern string, handler HandlerFunc, middleware ...Middleware)`

Register route handlers for HTTP methods.

```go
app.GET("/users", getUsersHandler)
app.POST("/users", createUserHandler, authMiddleware, validationMiddleware)
app.PUT("/users/:id", updateUserHandler, authMiddleware)
app.DELETE("/users/:id", deleteUserHandler, authMiddleware, adminMiddleware)
```

### Route Groups

#### `Group(prefix string, middleware ...Middleware) *Group`

Create a route group with shared prefix and middleware.

```go
api := app.Group("/api/v1", corsMiddleware, rateLimitMiddleware)
{
    usersGroup := api.Group("/users", authMiddleware)
    {
        usersGroup.GET("/", listUsers)
        usersGroup.POST("/", createUser)
    }
}
```

### Middleware

#### `Use(middleware ...Middleware)`

Register global middleware that applies to all routes.

```go
app.Use(loggingMiddleware, recoveryMiddleware)
```

### Server Control

#### `ListenAndServe()`

Start the HTTP server.

```go
app.ListenAndServe()
```

#### `SetRequestTimeout(timeout time.Duration)`

Set request timeout for all routes.

```go
app.SetRequestTimeout(60 * time.Second)
```

## Context

The request context containing request/response data and utilities.

### Request Data

#### `Param(key string) string`

Get URL parameter value.

```go
userID := c.Param("id")  // From route "/users/:id"
```

#### `Wildcard() string`

Get wildcard parameter value.

```go
filepath := c.Wildcard()  // From route "/files/*"
```

#### `Query(key string) string`

Get query parameter value.

```go
page := c.Query("page")  // From "?page=1"
```

#### `FormValue(key string) string`

Get form field value.

```go
name := c.FormValue("name")
```

#### `Bind(v interface{}) error`

Bind JSON request body to struct.

```go
var user User
err := c.Bind(&user)
```

### Response Methods

#### `JSON(status int, v interface{})`

Send JSON response.

```go
c.JSON(http.StatusOK, hikari.H{"message": "success"})
```

#### `String(status int, format string, values ...interface{})`

Send formatted string response.

```go
c.String(http.StatusOK, "Hello, %s!", name)
```

#### `Status(status int)`

Set response status code.

```go
c.Status(http.StatusNoContent)
```

#### `GetStatus() int`

Get current response status code.

```go
currentStatus := c.GetStatus()
```

#### `File(filePath string)`

Send file as response.

```go
c.File("./uploads/document.pdf")
```

### Headers

#### `SetHeader(key, value string)`

Set response header.

```go
c.SetHeader("Content-Type", "application/json")
```

#### `GetHeader(key string) string`

Get response header value.

```go
contentType := c.GetHeader("Content-Type")
```

### Context Storage

#### `Set(key string, value interface{})`

Store value in context.

```go
c.Set("user_id", 123)
```

#### `Get(key string) (interface{}, bool)`

Get stored value with existence check.

```go
if value, exists := c.Get("user_id"); exists {
    // Use value
}
```

#### `MustGet(key string) interface{}`

Get stored value (logs error if not found).

```go
userID := c.MustGet("user_id")
```

#### `GetString(key string) string`

Get string value from storage.

```go
userID := c.GetString("user_id")
```

#### `GetInt(key string) int`

Get int value from storage.

```go
count := c.GetInt("count")
```

#### `GetBool(key string) bool`

Get bool value from storage.

```go
isAuthenticated := c.GetBool("authenticated")
```

#### `Keys() []string`

Get all stored keys.

```go
keys := c.Keys()
```

### Context Interface

Hikari Context implements Go's `context.Context` interface:

#### `WithTimeout(timeout time.Duration) (context.Context, context.CancelFunc)`

Create context with timeout.

```go
ctx, cancel := c.WithTimeout(30 * time.Second)
defer cancel()
```

#### `WithCancel() (context.Context, context.CancelFunc)`

Create cancellable context.

```go
ctx, cancel := c.WithCancel()
defer cancel()
```

#### `WithValue(key, value interface{}) context.Context`

Create context with value.

```go
ctx := c.WithValue("key", "value")
```

#### `Value(key interface{}) interface{}`

Get context value.

```go
value := c.Value("key")
```

#### `Done() <-chan struct{}`

Get cancellation channel.

```go
select {
case <-c.Done():
    // Context was cancelled
}
```

#### `Err() error`

Get context error.

```go
if err := c.Err(); err != nil {
    // Handle context error
}
```

### Request Information

#### `Method() string`

Get HTTP method.

```go
method := c.Method()  // "GET", "POST", etc.
```

#### `Path() string`

Get request path.

```go
path := c.Path()  // "/api/users/123"
```

## WebSocket Context (v0.2.0)

The WebSocket context extends the standard Context with WebSocket-specific functionality.

### `type WSContext`

WebSocket context available in WebSocket handlers.

```go
type WebSocketHandler func(*WSContext)

app.WebSocket("/ws/chat", "chat_room", func(c *hikari.WSContext) {
    // WebSocket handler logic
})
```

### Message Handling

#### `IsTextMessage() bool`

Check if current message is text.

```go
if c.IsTextMessage() {
    message := c.GetMessage()
    // Process text message
}
```

#### `IsBinaryMessage() bool`

Check if current message is binary.

```go
if c.IsBinaryMessage() {
    data := c.GetBinaryMessage()
    // Process binary data
}
```

#### `GetMessage() string`

Get text message content.

```go
message := c.GetMessage()
```

#### `GetBinaryMessage() []byte`

Get binary message data.

```go
data := c.GetBinaryMessage()
```

#### `Bind(v interface{}) error`

Bind JSON message to struct.

```go
type ChatMessage struct {
    Type    string `json:"type"`
    Message string `json:"message"`
}

var msg ChatMessage
if err := c.Bind(&msg); err == nil {
    // Process structured message
}
```

### Sending Messages

#### `Send(data []byte) error`

Send raw bytes to the client.

```go
c.Send([]byte("Hello, WebSocket!"))
```

#### `String(text string) error`

Send text message to the client.

```go
c.String("Hello, WebSocket!")
```

#### `JSON(v interface{}) error`

Send JSON message to the client.

```go
response := map[string]string{
    "type": "response",
    "message": "Hello from server",
}
c.JSON(response)
```

#### `Broadcast(data []byte)`

Broadcast raw bytes to all connections in the hub.

```go
c.Broadcast([]byte("Server announcement"))
```

#### `BroadcastJSON(v interface{})`

Broadcast JSON message to all connections in the hub.

```go
announcement := map[string]string{
    "type": "announcement",
    "message": "New user joined",
}
c.BroadcastJSON(announcement)
```

#### `SendToConnection(connID string, data []byte) error`

Send message to specific connection by ID.

```go
c.SendToConnection("conn_123", []byte("Private message"))
```

### Connection Information

#### `ConnectionID() string`

Get unique connection identifier.

```go
connID := c.ConnectionID()
```

#### `HubName() string`

Get hub name for this connection.

```go
hubName := c.HubName()
```

#### `Request() *http.Request`

Get original HTTP request that initiated WebSocket.

```go
request := c.Request()
userAgent := request.Header.Get("User-Agent")
```

## WebSocket Configuration

### `type WebSocketConfig`

Configuration for WebSocket functionality.

```go
type WebSocketConfig struct {
    ReadBufferSize    int                           // Buffer size for reading
    WriteBufferSize   int                           // Buffer size for writing
    HandshakeTimeout  time.Duration                 // Handshake timeout
    CheckOrigin       func(*http.Request) bool      // Origin validation
    EnableCompression bool                          // Enable compression
    PingInterval      time.Duration                 // Ping interval
    PongTimeout       time.Duration                 // Pong timeout
    RegisterTimeout   time.Duration                 // Registration timeout
}
```

### `DefaultWebSocketConfig() *WebSocketConfig`

Get default WebSocket configuration.

```go
config := hikari.DefaultWebSocketConfig()
// Default values:
// ReadBufferSize: 1024
// WriteBufferSize: 1024
// HandshakeTimeout: 10s
// CheckOrigin: Allow all
// EnableCompression: true
// PingInterval: 30s
// PongTimeout: 60s
// RegisterTimeout: 30s
```

## WebSocket Hub

### `type WebSocketHub`

Hub manages multiple WebSocket connections for a specific channel/room.

#### `Broadcast(data []byte)`

Broadcast message to all connections in the hub.

```go
if hub, exists := app.GetWebSocketHub("chat_room"); exists {
    hub.Broadcast([]byte("Server message"))
}
```

### Hub Management

Hubs are automatically created when registering WebSocket routes, but can be accessed for external operations:

```go
// Register WebSocket route (creates hub if not exists)
app.WebSocket("/ws/notifications", "notifications", notificationHandler)

// Later, send notification from HTTP handler
app.POST("/api/notify", func(c *hikari.Context) {
    if hub, exists := app.GetWebSocketHub("notifications"); exists {
        notification := map[string]interface{}{
            "type": "alert",
            "message": "System maintenance in 5 minutes",
        }
        data, _ := json.Marshal(notification)
        hub.Broadcast(data)
        
        c.JSON(http.StatusOK, hikari.H{"status": "sent"})
    } else {
        c.JSON(http.StatusNotFound, hikari.H{"error": "Hub not found"})
    }
})
```

## Group

Route group for organizing related routes.

### HTTP Methods

Same as App methods but scoped to the group:

```go
users := app.Group("/users")
users.GET("/", listUsers)
users.POST("/", createUser)
users.GET("/:id", getUser)
```

### Nested Groups

#### `Group(prefix string, middleware ...Middleware) *Group`

Create nested group.

```go
api := app.Group("/api")
v1 := api.Group("/v1")
v2 := api.Group("/v2")
```

## Types

### `HandlerFunc`

HTTP handler function type.

```go
type HandlerFunc func(c *Context)

func userHandler(c *hikari.Context) {
    c.JSON(http.StatusOK, hikari.H{"message": "Hello"})
}
```

### `WebSocketHandler`

WebSocket handler function type.

```go
type WebSocketHandler func(c *WSContext)

func chatHandler(c *hikari.WSContext) {
    if c.IsTextMessage() {
        c.Broadcast([]byte(c.GetMessage()))
    }
}
```

### `Middleware`

Middleware function type that wraps handlers.

```go
type Middleware func(HandlerFunc) HandlerFunc

func loggingMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        start := time.Now()
        next(c)
        duration := time.Since(start)
        log.Printf("Request took %v", duration)
    }
}
```

### `H`

Convenient type for JSON responses.

```go
type H map[string]interface{}

// Usage
c.JSON(http.StatusOK, hikari.H{
    "message": "success",
    "data": data,
    "count": 10,
})
```

## Built-in Features

### Recovery Middleware

Automatically included - recovers from panics and logs them.

```go
// Automatically handles panics
app.GET("/panic", func(c *hikari.Context) {
    panic("Something went wrong")  // Will be caught and logged
})
```

### Request Logging

Automatically included - logs request details with timing and User-Agent.

```go
// Automatically logs all requests:
// 2024/01/15 10:30:45 [INFO] Request started method=GET path=/api/users
```

### Pattern Normalization

Route patterns are automatically normalized to prevent conflicts.

```go
// These are equivalent:
app.GET("/users/", handler)     // → "/users"
app.GET("//users", handler)     // → "/users"
app.GET("/api///v1/users", handler)  // → "/api/v1/users"
```

### WebSocket Connection Management

Automatic connection lifecycle management including:
- Connection registration and cleanup
- Hub-based message routing
- Ping/pong keepalive
- Graceful disconnect handling

## Configuration

### Server Configuration

#### Default Timeouts

- **Read Timeout**: 5 seconds
- **Write Timeout**: 5 seconds
- **Request Timeout**: 30 seconds (configurable per route)

#### Request Timeout Configuration

```go
// Set global request timeout
app.SetRequestTimeout(60 * time.Second)

// Routes automatically inherit this timeout
app.GET("/slow-endpoint", slowHandler)
```

### WebSocket Configuration

WebSocket functionality can be configured using `WebSocketConfig`:

```go
wsConfig := &hikari.WebSocketConfig{
    ReadBufferSize:    4096,                           // Larger buffer for high-throughput
    WriteBufferSize:   4096,
    HandshakeTimeout:  15 * time.Second,               // Allow more time for handshake
    CheckOrigin: func(r *http.Request) bool {          // Custom origin validation
        origin := r.Header.Get("Origin")
        return origin == "https://yourdomain.com"
    },
    EnableCompression: true,                           // Enable message compression
    PingInterval:      45 * time.Second,               // Custom ping interval
    PongTimeout:       90 * time.Second,               // Custom pong timeout
    RegisterTimeout:   60 * time.Second,               // Hub registration timeout
}

app.WithWebSocket(wsConfig)
```

### Production Configuration Example

```go
package main

import (
    "os"
    "time"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")
    
    // Configure request timeout based on environment
    if os.Getenv("ENV") == "production" {
        app.SetRequestTimeout(30 * time.Second)
    } else {
        app.SetRequestTimeout(60 * time.Second) // More lenient for development
    }
    
    // Production WebSocket config
    wsConfig := &hikari.WebSocketConfig{
        ReadBufferSize:    8192,
        WriteBufferSize:   8192,
        HandshakeTimeout:  10 * time.Second,
        CheckOrigin: func(r *http.Request) bool {
            allowedOrigins := []string{
                "https://yourdomain.com",
                "https://app.yourdomain.com",
            }
            origin := r.Header.Get("Origin")
            for _, allowed := range allowedOrigins {
                if origin == allowed {
                    return true
                }
            }
            return false
        },
        EnableCompression: true,
        PingInterval:      30 * time.Second,
        PongTimeout:       60 * time.Second,
    }
    app.WithWebSocket(wsConfig)
    
    // Your routes here...
    
    app.ListenAndServe()
}
```

### Graceful Shutdown

Hikari automatically handles graceful shutdown on SIGINT and SIGTERM signals with proper cleanup of:
- HTTP connections
- WebSocket connections and hubs
- Background goroutines
- Resource cleanup

## Migration Guide

### Upgrading to v0.2.0

#### New Features Available
- WebSocket support with `app.WebSocket()` and `WSContext`
- Enhanced route groups with middleware inheritance
- Pattern normalization and validation
- Extended HTTP methods support (OPTIONS, HEAD)

#### Breaking Changes
- None - v0.2.0 is fully backward compatible

#### New Best Practices
- Use route groups for better organization
- Implement WebSocket for real-time features
- Leverage middleware inheritance for cleaner code structure

```go
// Old approach (still works)
app.GET("/api/v1/users", usersHandler, authMiddleware)
app.GET("/api/v1/posts", postsHandler, authMiddleware)
app.GET("/api/v1/admin/stats", statsHandler, authMiddleware, adminMiddleware)

// New recommended approach
v1Group := app.Group("/api/v1", authMiddleware)
{
    v1Group.GET("/users", usersHandler)
    v1Group.GET("/posts", postsHandler)
    
    adminGroup := v1Group.Group("/admin", adminMiddleware)
    {
        adminGroup.GET("/stats", statsHandler)  // Inherits auth + admin middleware
    }
}

// Add WebSocket for real-time features
app.WithWebSocket(hikari.DefaultWebSocketConfig())
v1Group.WebSocket("/ws/notifications", "notifications", notificationHandler, authMiddleware)
```
