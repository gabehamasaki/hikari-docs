---
sidebar_position: 2
---

# Routing and Middleware

Hikari provides a powerful and flexible routing system with support for HTTP methods, route parameters, wildcards, route groups, and an advanced middleware system with inheritance.

## HTTP Methods

Hikari supports all standard HTTP methods:

```go
app := hikari.New(":8080")

app.GET("/users", getUsersHandler)
app.POST("/users", createUserHandler)
app.PUT("/users/:id", updateUserHandler)
app.PATCH("/users/:id", patchUserHandler)
app.DELETE("/users/:id", deleteUserHandler)
app.OPTIONS("/users", optionsHandler)
app.HEAD("/users/:id", headHandler)
```

## Route Groups

Route groups allow you to organize routes with shared prefixes and middleware, providing a clean and hierarchical structure for your API.

### Basic Route Groups

```go
app := hikari.New(":8080")

// API v1 group
v1Group := app.Group("/api/v1")
{
    v1Group.GET("/health", healthHandler)
    v1Group.GET("/version", versionHandler)

    // Users resource group
    usersGroup := v1Group.Group("/users")
    {
        usersGroup.GET("/", listUsers)       // GET /api/v1/users
        usersGroup.POST("/", createUser)     // POST /api/v1/users
        usersGroup.GET("/:id", getUser)      // GET /api/v1/users/:id
        usersGroup.PUT("/:id", updateUser)   // PUT /api/v1/users/:id
        usersGroup.DELETE("/:id", deleteUser) // DELETE /api/v1/users/:id
    }

    // Posts resource group
    postsGroup := v1Group.Group("/posts")
    {
        postsGroup.GET("/", listPosts)
        postsGroup.POST("/", createPost)
        postsGroup.GET("/:id", getPost)
    }
}
```

### Groups with Middleware

Apply middleware to entire groups for shared functionality:

```go
// Global CORS middleware
app.Use(corsMiddleware)

// API v1 with rate limiting
v1Group := app.Group("/api/v1", rateLimitMiddleware)
{
    // Public endpoints (only rate limiting)
    v1Group.GET("/health", healthHandler)

    // Auth group - public auth endpoints
    authGroup := v1Group.Group("/auth")
    {
        authGroup.POST("/login", loginHandler)
        authGroup.POST("/register", registerHandler)
        authGroup.POST("/logout", logoutHandler, authMiddleware) // Only logout needs auth
    }

    // Protected group - requires authentication
    protectedGroup := v1Group.Group("/protected", authMiddleware)
    {
        protectedGroup.GET("/profile", getProfile)
        protectedGroup.PUT("/profile", updateProfile)

        // Admin group - requires auth + admin role
        adminGroup := protectedGroup.Group("/admin", adminMiddleware)
        {
            adminGroup.GET("/users", adminListUsers)
            adminGroup.DELETE("/users/:id", adminDeleteUser)
        }
    }
}
```

### Nested Groups with Middleware Inheritance

Child groups automatically inherit middleware from their parent groups:

```go
// Parent group with auth middleware
apiGroup := app.Group("/api", authMiddleware)
{
    // Child group inherits auth + adds logging
    v1Group := apiGroup.Group("/v1", loggingMiddleware)
    {
        // Grandchild inherits auth + logging + adds admin check
        adminGroup := v1Group.Group("/admin", adminMiddleware)
        {
            // This endpoint has all 3 middlewares: auth → logging → admin
            adminGroup.GET("/users", getUsersHandler)
        }
    }
}

// Results in: GET /api/v1/admin/users
// Middleware execution order: authMiddleware → loggingMiddleware → adminMiddleware → getUsersHandler
```

## Route Parameters

### Dynamic Parameters

Use `:param` syntax for dynamic route segments:

```go
app.GET("/users/:id", func(c *hikari.Context) {
    userID := c.Param("id")
    c.JSON(http.StatusOK, hikari.H{
        "user_id": userID,
    })
})

// Multiple parameters
app.GET("/users/:userId/posts/:postId", func(c *hikari.Context) {
    userID := c.Param("userId")
    postID := c.Param("postId")
    c.JSON(http.StatusOK, hikari.H{
        "user_id": userID,
        "post_id": postID,
    })
})
```

### Wildcard Parameters

Use `*` for wildcard matching:

```go
app.GET("/files/*", func(c *hikari.Context) {
    filepath := c.Wildcard()
    c.String(http.StatusOK, "File path: %s", filepath)
})
```

## Middleware System

Hikari supports a powerful multi-level middleware system with inheritance and predictable execution order.

### Middleware Levels

There are three levels of middleware in Hikari:

1. **Global Middleware**: Applied to all routes
2. **Group Middleware**: Applied to all routes within a group (and inherited by child groups)
3. **Route Middleware**: Applied to specific routes

### Global Middleware

Applied to all routes across your entire application:

```go
app := hikari.New(":8080")

// Global CORS middleware
app.Use(func(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        c.SetHeader("Access-Control-Allow-Origin", "*")
        c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        c.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
        next(c) // Call next middleware
    }
})

// Global logging middleware
app.Use(loggingMiddleware)
```

### Group Middleware

Apply middleware to all routes within a group:

```go
// Protected API routes with multiple middlewares
protectedGroup := app.Group("/api/protected", authMiddleware, rateLimitMiddleware)
{
    protectedGroup.GET("/profile", getProfile)
    protectedGroup.POST("/posts", createPost)
}

// Nested groups inherit parent middleware
adminGroup := protectedGroup.Group("/admin", adminMiddleware) // Inherits auth + rate limit
{
    adminGroup.GET("/users", adminListUsers)   // Has auth + rate limit + admin middleware
    adminGroup.DELETE("/users/:id", adminDeleteUser)
}
```

### Route-Level Middleware

Apply middleware to specific routes:

```go
// Single middleware
app.GET("/public", publicHandler, loggingMiddleware)

// Multiple middleware on a single route
app.POST("/admin/users",
    createUserHandler,
    authMiddleware,
    adminMiddleware,
    auditMiddleware,
)

// Middleware with groups
v1Group := app.Group("/api/v1")
{
    // This route has group middleware + route-specific middleware
    v1Group.POST("/upload", uploadHandler, fileSizeMiddleware, virusScanMiddleware)
}
```

### Middleware Execution Order

Middleware is executed in this order:
1. Global middleware (in order of registration)
2. Group middleware (from parent to child groups)
3. Route-specific middleware (in order of definition)
4. Handler function

```go
app.Use(globalMiddleware1)     // 1st
app.Use(globalMiddleware2)     // 2nd

parentGroup := app.Group("/api", parentMiddleware)  // 3rd
{
    childGroup := parentGroup.Group("/v1", childMiddleware)  // 4th
    {
        // Execution order: global1 → global2 → parent → child → route → handler
        childGroup.GET("/users", handler, routeMiddleware)  // 5th, then handler
    }
}
```

## Middleware Examples

### CORS Middleware

```go
func corsMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        c.SetHeader("Access-Control-Allow-Origin", "*")
        c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        c.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

        if c.Method() == "OPTIONS" {
            c.Status(http.StatusOK)
            return
        }

        next(c) // Continue to next middleware/handler
    }
}
```

### Authentication Middleware

```go
func authMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        token := c.GetHeader("Authorization")
        if token == "" {
            c.JSON(http.StatusUnauthorized, hikari.H{
                "error": "Authorization header required",
            })
            return
        }

        // Validate token and set user context
        userID, err := validateToken(token)
        if err != nil {
            c.JSON(http.StatusUnauthorized, hikari.H{
                "error": "Invalid token",
            })
            return
        }

        c.Set("user_id", userID) // Store for next handlers
        next(c) // Continue to next middleware/handler
    }
}
```

### Rate Limiting Middleware

```go
func rateLimitMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        clientIP := c.Request.RemoteAddr

        if isRateLimited(clientIP) {
            c.JSON(http.StatusTooManyRequests, hikari.H{
                "error": "Rate limit exceeded",
                "retry_after": "60s",
            })
            return
        }

        next(c) // Continue to next middleware/handler
    }
}
```

### Logging Middleware

```go
func loggingMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        start := time.Now()

        next(c) // Execute handler

        // Log after handler execution
        duration := time.Since(start)
        fmt.Printf("Request: %s %s - %d - %v\n",
            c.Method(), c.Request.URL.Path,
            c.Writer.(*hikari.ResponseWriter).Status(),
            duration)
    }
}
```

### Admin Authorization Middleware

```go
func adminMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        userRole := c.GetString("user_role") // From previous auth middleware

        if userRole != "admin" {
            c.JSON(http.StatusForbidden, hikari.H{
                "error": "Admin access required",
            })
            return
        }

        next(c)
    }
}
```

## Static File Serving

Hikari provides flexible static file serving capabilities using wildcard routes:

### Basic Static File Serving

```go
// Serve files from ./static directory
app.GET("/static/*", func(c *hikari.Context) {
    filepath := c.Wildcard()
    c.File("./static/" + filepath)
})

// Example: GET /static/css/style.css serves ./static/css/style.css
```

### Secure Static File Serving

For production use, implement security checks:

```go
import (
    "os"
    "path/filepath"
    "strings"
)

func serveStatic(c *hikari.Context) {
    requestedPath := c.Wildcard()

    if requestedPath == "" {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "No file specified",
        })
        return
    }

    staticDir := "./static"
    fullPath := filepath.Join(staticDir, requestedPath)

    // Security check: prevent directory traversal
    absStaticDir, _ := filepath.Abs(staticDir)
    absFullPath, _ := filepath.Abs(fullPath)
    if !strings.HasPrefix(absFullPath, absStaticDir) {
        c.JSON(http.StatusForbidden, hikari.H{
            "error": "Access denied",
        })
        return
    }

    // Check if file exists
    if _, err := os.Stat(fullPath); os.IsNotExist(err) {
        c.JSON(http.StatusNotFound, hikari.H{
            "error": "File not found",
        })
        return
    }

    c.File(fullPath)
}

// Register secure static handler
app.GET("/static/*", serveStatic)
```

### Multiple Static Directories

```go
// Serve different types of content from different directories
app.GET("/images/*", func(c *hikari.Context) {
    c.File("./assets/images/" + c.Wildcard())
})

app.GET("/css/*", func(c *hikari.Context) {
    c.File("./assets/styles/" + c.Wildcard())
})

app.GET("/js/*", func(c *hikari.Context) {
    c.File("./assets/scripts/" + c.Wildcard())
})
```

### Static Files with Route Groups

```go
// Organize static routes in groups
staticGroup := app.Group("/assets")
{
    staticGroup.GET("/css/*", func(c *hikari.Context) {
        c.File("./static/css/" + c.Wildcard())
    })

    staticGroup.GET("/js/*", func(c *hikari.Context) {
        c.File("./static/js/" + c.Wildcard())
    })

    staticGroup.GET("/images/*", func(c *hikari.Context) {
        c.File("./static/images/" + c.Wildcard())
    })
}
```

## Pattern Normalization and Validation

Hikari automatically normalizes and validates route patterns to prevent conflicts and ensure consistency.

### Automatic Normalization

```go
// These routes are automatically normalized:
app.GET("/users/", handler)              // → "/users"
app.GET("//users//", handler)            // → "/users"
app.GET("/api///v1////users/", handler)  // → "/api/v1/users"

// Trailing slashes are removed except for root
app.GET("/", rootHandler)        // → "/" (unchanged)
app.GET("/users/", userHandler)  // → "/users"
```

### Pattern Validation

Hikari validates route patterns using built-in regex patterns:

```go
// Valid patterns
app.GET("/users", handler)           // ✅
app.GET("/users/:id", handler)       // ✅
app.GET("/files/*", handler)         // ✅
app.GET("/api/v1/posts/:id", handler) // ✅

// Invalid patterns will be caught during registration
// app.GET("", handler)              // ❌ Empty pattern
// app.GET("users", handler)         // ❌ Must start with /
```

### Building Complex Patterns

Group prefixes are properly combined with route patterns:

```go
apiGroup := app.Group("/api/v1")  // Normalized prefix
{
    usersGroup := apiGroup.Group("/users/")  // Normalized to "/users"
    {
        // Final route: /api/v1/users/:id/posts
        usersGroup.GET("/:id/posts/", handler)  // Normalized pattern
    }
}
```

## Complete RESTful API Example

Here's a comprehensive example showing route groups, middleware inheritance, and best practices:

```go
package main

import (
    "net/http"
    "strconv"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    // Global middleware
    app.Use(corsMiddleware())
    app.Use(requestLoggingMiddleware())

    // API v1 group with rate limiting
    v1Group := app.Group("/api/v1", rateLimitMiddleware())
    {
        // Public endpoints
        v1Group.GET("/health", healthCheck)
        v1Group.GET("/version", versionInfo)

        // Auth endpoints (public)
        authGroup := v1Group.Group("/auth")
        {
            authGroup.POST("/login", login)
            authGroup.POST("/register", register)
            authGroup.POST("/logout", logout, authMiddleware()) // Logout needs auth
            authGroup.POST("/refresh", refreshToken, authMiddleware())
        }

        // Protected endpoints - require authentication
        protectedGroup := v1Group.Group("/protected", authMiddleware())
        {
            // User profile
            protectedGroup.GET("/profile", getProfile)
            protectedGroup.PUT("/profile", updateProfile)

            // User posts
            postsGroup := protectedGroup.Group("/posts")
            {
                postsGroup.GET("/", getUserPosts)           // GET /api/v1/protected/posts
                postsGroup.POST("/", createPost)            // POST /api/v1/protected/posts
                postsGroup.GET("/:id", getPost)             // GET /api/v1/protected/posts/:id
                postsGroup.PUT("/:id", updatePost)          // PUT /api/v1/protected/posts/:id
                postsGroup.DELETE("/:id", deletePost)       // DELETE /api/v1/protected/posts/:id
            }

            // Admin endpoints - require auth + admin role
            adminGroup := protectedGroup.Group("/admin", adminMiddleware())
            {
                // User management
                usersGroup := adminGroup.Group("/users")
                {
                    usersGroup.GET("/", adminListUsers)         // Inherits: rate limit + auth + admin
                    usersGroup.GET("/:id", adminGetUser)
                    usersGroup.PUT("/:id", adminUpdateUser)
                    usersGroup.DELETE("/:id", adminDeleteUser)
                }

                // System management
                adminGroup.GET("/stats", systemStats)
                adminGroup.POST("/maintenance", toggleMaintenance, auditMiddleware())
            }
        }
    }

    // Static file serving
    app.GET("/static/*", serveStaticFiles)

    // WebSocket endpoints (if using WebSocket support)
    app.WithWebSocket(hikari.DefaultWebSocketConfig())
    app.WebSocket("/ws/chat", "general", chatHandler)

    app.ListenAndServe()
}

// Middleware functions would be implemented here...
// Handler functions would be implemented here...
```

This example demonstrates:
- **Hierarchical organization** with logical grouping
- **Middleware inheritance** from parent to child groups
- **RESTful patterns** for resource management
- **Security layers** with authentication and authorization
- **API versioning** with the `/api/v1` prefix
- **Mixed endpoints** (HTTP + WebSocket)
