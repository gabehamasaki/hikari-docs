---
sidebar_position: 3
---

# Context Management

The Hikari Context provides a rich interface for handling HTTP requests and responses, with built-in support for JSON binding, parameter access, storage, and Go's context interface.

## Request Data Access

### URL Parameters

```go
app.GET("/users/:id/posts/:postId", func(c *hikari.Context) {
    userID := c.Param("id")
    postID := c.Param("postId")

    c.JSON(http.StatusOK, hikari.H{
        "user_id": userID,
        "post_id": postID,
    })
})
```

### Query Parameters

```go
app.GET("/search", func(c *hikari.Context) {
    query := c.Query("q")
    page := c.Query("page")
    limit := c.Query("limit")

    c.JSON(http.StatusOK, hikari.H{
        "query": query,
        "page": page,
        "limit": limit,
    })
})
```

### Form Data

```go
app.POST("/contact", func(c *hikari.Context) {
    name := c.FormValue("name")
    email := c.FormValue("email")
    message := c.FormValue("message")

    // Process form data
    c.JSON(http.StatusOK, hikari.H{
        "message": "Form submitted successfully",
    })
})
```

### JSON Binding

```go
type User struct {
    Name  string `json:"name"`
    Email string `json:"email"`
    Age   int    `json:"age"`
}

app.POST("/users", func(c *hikari.Context) {
    var user User
    if err := c.Bind(&user); err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid JSON format",
        })
        return
    }

    // Process user data
    c.JSON(http.StatusCreated, hikari.H{
        "user": user,
        "message": "User created successfully",
    })
})
```

## Response Methods

### JSON Responses

```go
app.GET("/api/data", func(c *hikari.Context) {
    data := map[string]interface{}{
        "message": "Hello, World!",
        "timestamp": time.Now(),
        "status": "success",
    }
    c.JSON(http.StatusOK, data)
})
```

### String Responses

```go
app.GET("/health", func(c *hikari.Context) {
    c.String(http.StatusOK, "Server is running at %s", time.Now().Format(time.RFC3339))
})
```

### File Responses

```go
app.GET("/download/:filename", func(c *hikari.Context) {
    filename := c.Param("filename")
    filepath := "./uploads/" + filename
    c.File(filepath)
})
```

### Custom Status Codes

```go
app.POST("/webhook", func(c *hikari.Context) {
    // Process webhook
    c.Status(http.StatusAccepted)
})
```

## Headers

### Setting Headers

```go
app.GET("/api/data", func(c *hikari.Context) {
    c.SetHeader("X-API-Version", "1.0")
    c.SetHeader("Cache-Control", "no-cache")

    c.JSON(http.StatusOK, hikari.H{
        "data": "example",
    })
})
```

### Reading Headers

```go
app.POST("/api/data", func(c *hikari.Context) {
    contentType := c.GetHeader("Content-Type")
    userAgent := c.Request.Header.Get("User-Agent")

    c.JSON(http.StatusOK, hikari.H{
        "content_type": contentType,
        "user_agent": userAgent,
    })
})
```

## Context Storage

Hikari provides thread-safe storage for sharing data between middleware and handlers:

### Basic Storage Operations

```go
// Middleware setting data
func authMiddleware(c *hikari.Context) {
    token := c.GetHeader("Authorization")
    userID := validateToken(token) // Your validation logic

    // Store user data in context
    c.Set("user_id", userID)
    c.Set("authenticated", true)
}

// Handler accessing stored data
app.GET("/profile", func(c *hikari.Context) {
    userID := c.GetString("user_id")
    isAuth := c.GetBool("authenticated")

    if !isAuth {
        c.JSON(http.StatusUnauthorized, hikari.H{"error": "Unauthorized"})
        return
    }

    c.JSON(http.StatusOK, hikari.H{
        "user_id": userID,
        "profile": "user profile data",
    })
}, authMiddleware)
```

### Typed Storage Access

```go
app.Use(func(c *hikari.Context) {
    c.Set("string_value", "hello")
    c.Set("int_value", 42)
    c.Set("bool_value", true)
})

app.GET("/data", func(c *hikari.Context) {
    str := c.GetString("string_value")  // Returns "hello" or ""
    num := c.GetInt("int_value")        // Returns 42 or 0
    flag := c.GetBool("bool_value")     // Returns true or false

    c.JSON(http.StatusOK, hikari.H{
        "string": str,
        "number": num,
        "boolean": flag,
    })
})
```

### Safe Storage Access

```go
app.GET("/safe-access", func(c *hikari.Context) {
    // Check if value exists
    if value, exists := c.Get("some_key"); exists {
        c.JSON(http.StatusOK, hikari.H{"value": value})
    } else {
        c.JSON(http.StatusNotFound, hikari.H{"error": "Key not found"})
    }

    // Must get (logs error if not found)
    value := c.MustGet("required_key")
    if value == nil {
        c.JSON(http.StatusInternalServerError, hikari.H{"error": "Required data missing"})
        return
    }
})
```

### List All Keys

```go
app.GET("/debug/context", func(c *hikari.Context) {
    keys := c.Keys()
    c.JSON(http.StatusOK, hikari.H{
        "stored_keys": keys,
    })
})
```

## Go Context Interface

Hikari's Context implements Go's standard `context.Context` interface:

### Timeouts and Cancellation

```go
app.POST("/long-operation", func(c *hikari.Context) {
    // Create context with timeout
    ctx, cancel := c.WithTimeout(30 * time.Second)
    defer cancel()

    // Use context in your operations
    result, err := performLongOperation(ctx)
    if err != nil {
        if ctx.Err() == context.DeadlineExceeded {
            c.JSON(http.StatusRequestTimeout, hikari.H{
                "error": "Operation timed out",
            })
            return
        }
        c.JSON(http.StatusInternalServerError, hikari.H{
            "error": err.Error(),
        })
        return
    }

    c.JSON(http.StatusOK, hikari.H{
        "result": result,
    })
})
```

### Context Values

```go
app.Use(func(c *hikari.Context) {
    // Set context value
    newCtx := c.WithValue("request_id", generateRequestID())
    // Note: This creates a new context, doesn't modify the original
})

app.GET("/api/data", func(c *hikari.Context) {
    // Access context values
    requestID := c.Value("request_id")

    c.JSON(http.StatusOK, hikari.H{
        "request_id": requestID,
        "data": "example",
    })
})
```

### Context Cancellation

```go
func performLongOperation(ctx context.Context) (string, error) {
    select {
    case <-time.After(10 * time.Second):
        return "Operation completed", nil
    case <-ctx.Done():
        return "", ctx.Err()
    }
}
```

## Request Information

Access various request properties:

```go
app.Use(func(c *hikari.Context) {
    method := c.Method()        // GET, POST, etc.
    path := c.Path()           // /api/users/123
    status := c.GetStatus()    // Current response status

    c.Logger.Info("Request details",
        zap.String("method", method),
        zap.String("path", path),
        zap.Int("status", status),
    )
})
```
