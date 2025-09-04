---
sidebar_position: 4
---

# API Reference

Complete API reference for all Hikari types and methods.

## App

The main application instance.

### `hikari.New(addr string) *App`

Creates a new Hikari application instance.

```go
app := hikari.New(":8080")
```

### HTTP Methods

#### `GET(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `POST(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `PUT(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `PATCH(pattern string, handler HandlerFunc, middleware ...Middleware)`
#### `DELETE(pattern string, handler HandlerFunc, middleware ...Middleware)`

Register route handlers for HTTP methods.

```go
app.GET("/users", getUsersHandler)
app.POST("/users", createUserHandler, authMiddleware, validationMiddleware)
```

### Route Groups

#### `Group(prefix string, middleware ...Middleware) *Group`

Create a route group with shared prefix and middleware.

```go
api := app.Group("/api/v1", corsMiddleware, authMiddleware)
```

### Middleware

#### `Use(middleware ...Middleware)`

Register global middleware.

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

```go
type HandlerFunc func(c *Context)
```

### `Middleware`

```go
type Middleware func(HandlerFunc) HandlerFunc
```

### `H`

Convenient type for JSON responses.

```go
type H map[string]interface{}

// Usage
c.JSON(http.StatusOK, hikari.H{
    "message": "success",
    "data": data,
})
```

## Built-in Middleware

### Recovery Middleware

Automatically included - recovers from panics and logs them.

### Request Logging

Automatically included - logs request details with timing and User-Agent.

## Configuration

### Default Timeouts

- **Read Timeout**: 5 seconds
- **Write Timeout**: 5 seconds
- **Request Timeout**: 30 seconds (configurable)

### Graceful Shutdown

Hikari automatically handles graceful shutdown on SIGINT and SIGTERM signals.
