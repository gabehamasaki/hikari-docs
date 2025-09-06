---
sidebar_position: 4
---

# Examples

Practical examples demonstrating Hikari's features and capabilities, including the new v0.2.0 features like WebSocket support, route groups, and enhanced middleware.

## Getting Started Examples

### Hello World

```go
package main

import (
    "net/http"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    app.GET("/", func(c *hikari.Context) {
        c.JSON(http.StatusOK, hikari.H{
            "message": "Hello, Hikari!",
            "version": "0.2.0",
        })
    })

    app.ListenAndServe()
}
```

### RESTful API with Route Groups

```go
package main

import (
    "net/http"
    "strconv"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

type User struct {
    ID    int    `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

var users = []User{
    {1, "Alice", "alice@example.com"},
    {2, "Bob", "bob@example.com"},
}

func main() {
    app := hikari.New(":8080")

    // Global CORS middleware
    app.Use(corsMiddleware)

    // API v1 group
    v1Group := app.Group("/api/v1")
    {
        // Users resource group
        usersGroup := v1Group.Group("/users")
        {
            usersGroup.GET("/", getUsers)
            usersGroup.POST("/", createUser)
            usersGroup.GET("/:id", getUser)
            usersGroup.PUT("/:id", updateUser)
            usersGroup.DELETE("/:id", deleteUser)
        }

        // Health check
        v1Group.GET("/health", func(c *hikari.Context) {
            c.JSON(http.StatusOK, hikari.H{
                "status": "healthy",
                "users_count": len(users),
            })
        })
    }

    app.ListenAndServe()
}

// Handlers
func getUsers(c *hikari.Context) {
    c.JSON(http.StatusOK, hikari.H{"users": users})
}

func createUser(c *hikari.Context) {
    var newUser User
    if err := c.BindJSON(&newUser); err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{"error": err.Error()})
        return
    }
    
    newUser.ID = len(users) + 1
    users = append(users, newUser)
    c.JSON(http.StatusCreated, newUser)
}

func getUser(c *hikari.Context) {
    id, _ := strconv.Atoi(c.Param("id"))
    for _, user := range users {
        if user.ID == id {
            c.JSON(http.StatusOK, user)
            return
        }
    }
    c.JSON(http.StatusNotFound, hikari.H{"error": "User not found"})
}

func updateUser(c *hikari.Context) {
    id, _ := strconv.Atoi(c.Param("id"))
    for i, user := range users {
        if user.ID == id {
            if err := c.BindJSON(&users[i]); err != nil {
                c.JSON(http.StatusBadRequest, hikari.H{"error": err.Error()})
                return
            }
            users[i].ID = id // Preserve ID
            c.JSON(http.StatusOK, users[i])
            return
        }
    }
    c.JSON(http.StatusNotFound, hikari.H{"error": "User not found"})
}

func deleteUser(c *hikari.Context) {
    id, _ := strconv.Atoi(c.Param("id"))
    for i, user := range users {
        if user.ID == id {
            users = append(users[:i], users[i+1:]...)
            c.JSON(http.StatusOK, hikari.H{"message": "User deleted"})
            return
        }
    }
    c.JSON(http.StatusNotFound, hikari.H{"error": "User not found"})
}

func corsMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        c.SetHeader("Access-Control-Allow-Origin", "*")
        c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        c.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
        
        if c.Method() == "OPTIONS" {
            c.Status(http.StatusOK)
            return
        }
        
        next(c)
    }
}
```

## WebSocket Examples

### Basic WebSocket Chat

```go
package main

import (
    "encoding/json"
    "net/http"
    "time"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

type ChatMessage struct {
    Type     string `json:"type"`
    Username string `json:"username"`
    Message  string `json:"message"`
    Time     string `json:"time"`
}

func main() {
    app := hikari.New(":8080")

    // Configure WebSocket
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

    // WebSocket chat endpoint
    app.WebSocket("/ws/chat", "general", chatHandler)

    // Serve static files for chat interface
    app.GET("/", func(c *hikari.Context) {
        c.File("./static/chat.html")
    })
    app.GET("/static/*", func(c *hikari.Context) {
        c.File("./static/" + c.Wildcard())
    })

    // REST API for chat
    app.GET("/api/rooms", func(c *hikari.Context) {
        c.JSON(http.StatusOK, hikari.H{
            "rooms": []string{"general"},
        })
    })

    app.ListenAndServe()
}

func chatHandler(c *hikari.WSContext) {
    if c.IsTextMessage() {
        var msg ChatMessage
        if err := c.Bind(&msg); err == nil {
            msg.Time = time.Now().Format("15:04:05")
            
            switch msg.Type {
            case "join":
                joinMsg := ChatMessage{
                    Type:     "user_joined",
                    Username: msg.Username,
                    Message:  msg.Username + " entrou no chat",
                    Time:     msg.Time,
                }
                c.BroadcastJSON(joinMsg)
                
            case "message":
                // Broadcast message to all connections
                c.BroadcastJSON(msg)
                
            case "leave":
                leaveMsg := ChatMessage{
                    Type:     "user_left",
                    Username: msg.Username,
                    Message:  msg.Username + " saiu do chat",
                    Time:     msg.Time,
                }
                c.BroadcastJSON(leaveMsg)
            }
        }
    }
}
```

### Multi-Room Chat with Authentication

```go
package main

import (
    "net/http"
    "time"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")
    app.WithWebSocket(hikari.DefaultWebSocketConfig())

    // Public chat rooms
    app.WebSocket("/ws/general", "general", chatHandler)
    app.WebSocket("/ws/tech", "tech", chatHandler)
    app.WebSocket("/ws/random", "random", chatHandler)

    // VIP room with authentication
    app.WebSocket("/ws/vip", "vip", vipChatHandler, vipAuthMiddleware)

    // API endpoints
    v1Group := app.Group("/api/v1")
    {
        v1Group.GET("/rooms", listRooms)
        v1Group.GET("/rooms/:room/stats", getRoomStats)
        v1Group.POST("/rooms/:room/message", sendMessage)
    }

    app.ListenAndServe()
}

func chatHandler(c *hikari.WSContext) {
    if c.IsTextMessage() {
        var msg map[string]interface{}
        if err := c.Bind(&msg); err == nil {
            // Add timestamp and room info
            msg["timestamp"] = time.Now().Unix()
            msg["room"] = c.HubName()
            
            c.BroadcastJSON(msg)
        }
    }
}

func vipChatHandler(c *hikari.WSContext) {
    // VIP users get enhanced features
    if c.IsTextMessage() {
        var msg map[string]interface{}
        if err := c.Bind(&msg); err == nil {
            msg["timestamp"] = time.Now().Unix()
            msg["room"] = c.HubName()
            msg["vip"] = true // Mark as VIP message
            
            c.BroadcastJSON(msg)
        }
    }
}

func vipAuthMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        token := c.Query("token")
        if token != "vip123" {
            c.JSON(401, hikari.H{"error": "Invalid VIP token"})
            return
        }
        c.Set("vip_user", true)
        next(c)
    }
}

func listRooms(c *hikari.Context) {
    c.JSON(http.StatusOK, hikari.H{
        "rooms": []string{"general", "tech", "random", "vip"},
    })
}

func getRoomStats(c *hikari.Context) {
    roomName := c.Param("room")
    if hub, exists := app.GetWebSocketHub(roomName); exists {
        c.JSON(http.StatusOK, hikari.H{
            "room":   roomName,
            "active": true,
        })
    } else {
        c.JSON(http.StatusNotFound, hikari.H{"error": "Room not found"})
    }
}

func sendMessage(c *hikari.Context) {
    roomName := c.Param("room")
    if hub, exists := app.GetWebSocketHub(roomName); exists {
        var msg map[string]interface{}
        if err := c.BindJSON(&msg); err != nil {
            c.JSON(http.StatusBadRequest, hikari.H{"error": err.Error()})
            return
        }
        
        msg["source"] = "api"
        msg["timestamp"] = time.Now().Unix()
        
        data, _ := json.Marshal(msg)
        hub.Broadcast(data)
        
        c.JSON(http.StatusOK, hikari.H{"status": "sent"})
    } else {
        c.JSON(http.StatusNotFound, hikari.H{"error": "Room not found"})
    }
}
```

## Middleware Examples

### Complete Middleware Stack

```go
package main

import (
    "fmt"
    "net/http"
    "time"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    // Global middleware
    app.Use(requestLoggingMiddleware())
    app.Use(corsMiddleware())

    // API v1 with rate limiting
    v1Group := app.Group("/api/v1", rateLimitMiddleware())
    {
        // Public endpoints
        v1Group.GET("/health", healthCheck)

        // Protected endpoints with authentication
        protectedGroup := v1Group.Group("/protected", authMiddleware())
        {
            protectedGroup.GET("/profile", getProfile)

            // Admin endpoints with additional authorization
            adminGroup := protectedGroup.Group("/admin", adminMiddleware())
            {
                adminGroup.GET("/users", adminGetUsers)
                adminGroup.POST("/maintenance", toggleMaintenance, auditMiddleware())
            }
        }
    }

    app.ListenAndServe()
}

// Middleware implementations
func requestLoggingMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            start := time.Now()
            
            next(c)
            
            duration := time.Since(start)
            fmt.Printf("[%s] %s %s - %v\n", 
                time.Now().Format("2006/01/02 15:04:05"),
                c.Method(), 
                c.Request.URL.Path, 
                duration)
        }
    }
}

func corsMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            c.SetHeader("Access-Control-Allow-Origin", "*")
            c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
            c.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
            
            if c.Method() == "OPTIONS" {
                c.Status(http.StatusOK)
                return
            }
            
            next(c)
        }
    }
}

func rateLimitMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            // Simple rate limiting (in production, use Redis or similar)
            clientIP := c.Request.RemoteAddr
            if isRateLimited(clientIP) {
                c.JSON(http.StatusTooManyRequests, hikari.H{
                    "error": "Rate limit exceeded",
                })
                return
            }
            next(c)
        }
    }
}

func authMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            token := c.GetHeader("Authorization")
            if token == "" {
                c.JSON(http.StatusUnauthorized, hikari.H{
                    "error": "Authorization header required",
                })
                return
            }
            
            userID, err := validateToken(token)
            if err != nil {
                c.JSON(http.StatusUnauthorized, hikari.H{
                    "error": "Invalid token",
                })
                return
            }
            
            c.Set("user_id", userID)
            next(c)
        }
    }
}

func adminMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            userRole := getUserRole(c.GetString("user_id"))
            if userRole != "admin" {
                c.JSON(http.StatusForbidden, hikari.H{
                    "error": "Admin access required",
                })
                return
            }
            next(c)
        }
    }
}

func auditMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            userID := c.GetString("user_id")
            action := c.Request.URL.Path
            
            // Log admin action before execution
            fmt.Printf("AUDIT: User %s performing %s %s\n", 
                userID, c.Method(), action)
            
            next(c)
        }
    }
}

// Helper functions (implement according to your needs)
func isRateLimited(clientIP string) bool { return false }
func validateToken(token string) (string, error) { return "user123", nil }
func getUserRole(userID string) string { return "admin" }

// Handler functions
func healthCheck(c *hikari.Context) {
    c.JSON(http.StatusOK, hikari.H{"status": "healthy"})
}

func getProfile(c *hikari.Context) {
    userID := c.GetString("user_id")
    c.JSON(http.StatusOK, hikari.H{
        "user_id": userID,
        "profile": "User profile data",
    })
}

func adminGetUsers(c *hikari.Context) {
    c.JSON(http.StatusOK, hikari.H{"users": []string{"user1", "user2"}})
}

func toggleMaintenance(c *hikari.Context) {
    c.JSON(http.StatusOK, hikari.H{"maintenance_mode": "enabled"})
}
```

## File Upload Example

```go
package main

import (
    "fmt"
    "io"
    "net/http"
    "os"
    "path/filepath"
    "time"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

type FileInfo struct {
    ID          string    `json:"id"`
    Name        string    `json:"name"`
    Size        int64     `json:"size"`
    ContentType string    `json:"content_type"`
    UploadedAt  time.Time `json:"uploaded_at"`
    Path        string    `json:"path"`
}

var files = make(map[string]*FileInfo)
var uploadDir = "./uploads"

func main() {
    app := hikari.New(":8082")

    // Create uploads directory
    os.MkdirAll(uploadDir, 0755)

    // Global CORS middleware
    app.Use(corsMiddleware())

    // Root information
    app.GET("/", func(c *hikari.Context) {
        c.JSON(http.StatusOK, hikari.H{
            "service":  "file-upload-api",
            "version":  "1.0.0",
            "features": []string{"single upload", "multiple upload", "file management"},
        })
    })

    // API v1 group
    v1Group := app.Group("/api/v1")
    {
        // File management routes
        filesGroup := v1Group.Group("/files")
        {
            filesGroup.GET("/", listFiles)
            filesGroup.GET("/:id", getFileInfo)
            filesGroup.DELETE("/:id", deleteFile)
        }

        // Upload routes
        uploadGroup := v1Group.Group("/upload")
        {
            uploadGroup.POST("/", uploadFile)
            uploadGroup.POST("/multiple", uploadMultipleFiles)
        }

        // Download routes
        v1Group.GET("/download/:id", downloadFile)

        // Health check
        v1Group.GET("/health", func(c *hikari.Context) {
            c.JSON(http.StatusOK, hikari.H{
                "status": "healthy",
                "files_count": len(files),
                "upload_directory": uploadDir,
            })
        })
    }

    // Static file serving
    app.GET("/static/*", serveStatic)

    fmt.Println("📁 File Upload Server running on http://localhost:8082")
    app.ListenAndServe()
}

func uploadFile(c *hikari.Context) {
    err := c.Request.ParseMultipartForm(10 << 20) // 10MB
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{"error": "Unable to parse form"})
        return
    }

    file, header, err := c.Request.FormFile("file")
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{"error": "No file uploaded"})
        return
    }
    defer file.Close()

    // Validate file size
    if header.Size > 10<<20 {
        c.JSON(http.StatusBadRequest, hikari.H{"error": "File too large (max 10MB)"})
        return
    }

    // Generate unique filename
    fileID := generateFileID()
    fileExt := filepath.Ext(header.Filename)
    fileName := fileID + fileExt
    filePath := filepath.Join(uploadDir, fileName)

    // Create destination file
    dst, err := os.Create(filePath)
    if err != nil {
        c.JSON(http.StatusInternalServerError, hikari.H{"error": "Unable to create file"})
        return
    }
    defer dst.Close()

    // Copy uploaded file
    size, err := io.Copy(dst, file)
    if err != nil {
        c.JSON(http.StatusInternalServerError, hikari.H{"error": "Unable to save file"})
        return
    }

    // Store metadata
    fileInfo := &FileInfo{
        ID:          fileID,
        Name:        header.Filename,
        Size:        size,
        ContentType: header.Header.Get("Content-Type"),
        UploadedAt:  time.Now(),
        Path:        fileName,
    }
    files[fileID] = fileInfo

    c.JSON(http.StatusCreated, hikari.H{
        "message":      "File uploaded successfully",
        "file":         fileInfo,
        "download_url": fmt.Sprintf("/api/v1/download/%s", fileID),
        "static_url":   fmt.Sprintf("/static/%s", fileName),
    })
}

func uploadMultipleFiles(c *hikari.Context) {
    err := c.Request.ParseMultipartForm(50 << 20) // 50MB total
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{"error": "Unable to parse form"})
        return
    }

    form := c.Request.MultipartForm
    uploadedFiles := form.File["files"]

    if len(uploadedFiles) == 0 {
        c.JSON(http.StatusBadRequest, hikari.H{"error": "No files uploaded"})
        return
    }

    var results []hikari.H
    var errors []hikari.H

    for i, header := range uploadedFiles {
        file, err := header.Open()
        if err != nil {
            errors = append(errors, hikari.H{
                "file": header.Filename,
                "error": "Unable to open file",
            })
            continue
        }

        if header.Size > 10<<20 {
            file.Close()
            errors = append(errors, hikari.H{
                "file": header.Filename,
                "error": "File too large (max 10MB)",
            })
            continue
        }

        // Generate unique filename with index
        fileID := fmt.Sprintf("%s_%d", generateFileID(), i)
        fileExt := filepath.Ext(header.Filename)
        fileName := fileID + fileExt
        filePath := filepath.Join(uploadDir, fileName)

        dst, err := os.Create(filePath)
        if err != nil {
            file.Close()
            errors = append(errors, hikari.H{
                "file": header.Filename,
                "error": "Unable to create file",
            })
            continue
        }

        size, err := io.Copy(dst, file)
        dst.Close()
        file.Close()

        if err != nil {
            os.Remove(filePath)
            errors = append(errors, hikari.H{
                "file": header.Filename,
                "error": "Unable to save file",
            })
            continue
        }

        fileInfo := &FileInfo{
            ID:          fileID,
            Name:        header.Filename,
            Size:        size,
            ContentType: header.Header.Get("Content-Type"),
            UploadedAt:  time.Now(),
            Path:        fileName,
        }
        files[fileID] = fileInfo

        results = append(results, hikari.H{
            "file":         fileInfo,
            "download_url": fmt.Sprintf("/api/v1/download/%s", fileID),
            "static_url":   fmt.Sprintf("/static/%s", fileName),
        })
    }

    response := hikari.H{
        "message":        fmt.Sprintf("Processed %d files", len(uploadedFiles)),
        "uploaded_files": results,
        "uploaded_count": len(results),
        "total_count":    len(uploadedFiles),
    }

    if len(errors) > 0 {
        response["errors"] = errors
        response["error_count"] = len(errors)
    }

    statusCode := http.StatusCreated
    if len(errors) == len(uploadedFiles) {
        statusCode = http.StatusBadRequest
    } else if len(errors) > 0 {
        statusCode = http.StatusPartialContent
    }

    c.JSON(statusCode, response)
}

func listFiles(c *hikari.Context) {
    var fileList []*FileInfo
    for _, fileInfo := range files {
        fileList = append(fileList, fileInfo)
    }

    c.JSON(http.StatusOK, hikari.H{
        "files": fileList,
        "count": len(fileList),
    })
}

func getFileInfo(c *hikari.Context) {
    fileID := c.Param("id")
    fileInfo, exists := files[fileID]
    if !exists {
        c.JSON(http.StatusNotFound, hikari.H{"error": "File not found"})
        return
    }

    c.JSON(http.StatusOK, hikari.H{
        "file":         fileInfo,
        "download_url": fmt.Sprintf("/api/v1/download/%s", fileID),
        "static_url":   fmt.Sprintf("/static/%s", fileInfo.Path),
    })
}

func downloadFile(c *hikari.Context) {
    fileID := c.Param("id")
    fileInfo, exists := files[fileID]
    if !exists {
        c.JSON(http.StatusNotFound, hikari.H{"error": "File not found"})
        return
    }

    filePath := filepath.Join(uploadDir, fileInfo.Path)
    if _, err := os.Stat(filePath); os.IsNotExist(err) {
        delete(files, fileID)
        c.JSON(http.StatusNotFound, hikari.H{"error": "File not found on disk"})
        return
    }

    c.SetHeader("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", fileInfo.Name))
    c.SetHeader("Content-Type", fileInfo.ContentType)
    http.ServeFile(c.Writer, c.Request, filePath)
}

func deleteFile(c *hikari.Context) {
    fileID := c.Param("id")
    fileInfo, exists := files[fileID]
    if !exists {
        c.JSON(http.StatusNotFound, hikari.H{"error": "File not found"})
        return
    }

    filePath := filepath.Join(uploadDir, fileInfo.Path)
    if err := os.Remove(filePath); err != nil && !os.IsNotExist(err) {
        c.JSON(http.StatusInternalServerError, hikari.H{"error": "Unable to delete file"})
        return
    }

    delete(files, fileID)
    c.JSON(http.StatusOK, hikari.H{"message": "File deleted successfully"})
}

func serveStatic(c *hikari.Context) {
    filePath := c.Wildcard()
    if filePath == "" {
        c.JSON(http.StatusBadRequest, hikari.H{"error": "No file specified"})
        return
    }

    fullPath := filepath.Join(uploadDir, filePath)
    
    // Security check
    absUploadDir, _ := filepath.Abs(uploadDir)
    absFullPath, _ := filepath.Abs(fullPath)
    if !strings.HasPrefix(absFullPath, absUploadDir) {
        c.JSON(http.StatusForbidden, hikari.H{"error": "Access denied"})
        return
    }

    c.File(fullPath)
}

func corsMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            c.SetHeader("Access-Control-Allow-Origin", "*")
            c.SetHeader("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
            c.SetHeader("Access-Control-Allow-Headers", "Content-Type")

            if c.Method() == "OPTIONS" {
                c.Status(http.StatusOK)
                return
            }

            next(c)
        }
    }
}

func generateFileID() string {
    return fmt.Sprintf("file_%d", time.Now().UnixNano())
}
```

## Production-Ready Example

This example demonstrates a production-ready setup with all v0.2.0 features:

```go
package main

import (
    "context"
    "fmt"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    // Global middleware stack
    app.Use(securityHeadersMiddleware())
    app.Use(requestLoggingMiddleware())
    app.Use(corsMiddleware())

    // WebSocket configuration
    wsConfig := &hikari.WebSocketConfig{
        ReadBufferSize:    4096,
        WriteBufferSize:   4096,
        HandshakeTimeout:  10 * time.Second,
        CheckOrigin: func(r *http.Request) bool {
            origin := r.Header.Get("Origin")
            return origin == "https://yourdomain.com" || 
                   (os.Getenv("ENV") == "development" && origin == "http://localhost:3000")
        },
        EnableCompression: true,
        PingInterval:      30 * time.Second,
        PongTimeout:       60 * time.Second,
    }
    app.WithWebSocket(wsConfig)

    // Public routes
    app.GET("/", indexHandler)
    app.GET("/health", healthCheck)

    // Static file serving with security
    app.GET("/static/*", secureStaticHandler)

    // API v1 with rate limiting
    v1Group := app.Group("/api/v1", rateLimitMiddleware())
    {
        // Public API endpoints
        v1Group.GET("/version", versionInfo)

        // Authentication endpoints
        authGroup := v1Group.Group("/auth")
        {
            authGroup.POST("/login", login)
            authGroup.POST("/register", register)
            authGroup.POST("/logout", logout, authMiddleware())
            authGroup.POST("/refresh", refreshToken, authMiddleware())
        }

        // Protected API endpoints
        protectedGroup := v1Group.Group("/protected", authMiddleware())
        {
            protectedGroup.GET("/profile", getProfile)
            protectedGroup.PUT("/profile", updateProfile)

            // WebSocket endpoints for real-time features
            protectedGroup.WebSocket("/ws/notifications", "notifications", notificationHandler)

            // Admin endpoints
            adminGroup := protectedGroup.Group("/admin", adminMiddleware())
            {
                adminGroup.GET("/stats", systemStats)
                adminGroup.GET("/users", adminListUsers)
                adminGroup.WebSocket("/ws/admin", "admin_channel", adminChatHandler)
            }
        }
    }

    // Public WebSocket endpoints
    app.WebSocket("/ws/public", "public_chat", publicChatHandler)

    // Graceful shutdown
    setupGracefulShutdown(app)

    fmt.Println("🚀 Production server starting on :8080")
    app.ListenAndServe()
}

func setupGracefulShutdown(app *hikari.App) {
    c := make(chan os.Signal, 1)
    signal.Notify(c, os.Interrupt, syscall.SIGTERM)

    go func() {
        <-c
        fmt.Println("\n🛑 Shutting down gracefully...")
        
        ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
        defer cancel()

        // Close WebSocket connections, database connections, etc.
        // app.Shutdown(ctx)

        fmt.Println("✅ Server stopped")
        os.Exit(0)
    }()
}

// Production middleware implementations
func securityHeadersMiddleware() hikari.Middleware {
    return func(next hikari.HandlerFunc) hikari.HandlerFunc {
        return func(c *hikari.Context) {
            c.SetHeader("X-Content-Type-Options", "nosniff")
            c.SetHeader("X-Frame-Options", "DENY")
            c.SetHeader("X-XSS-Protection", "1; mode=block")
            c.SetHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
            c.SetHeader("Content-Security-Policy", "default-src 'self'")
            next(c)
        }
    }
}

// Other middleware and handlers would be implemented here...
```

## Repository Examples

For complete working examples with more detailed implementations, check out the official repository:

- **[Chat App](https://github.com/gabehamasaki/hikari-go/tree/main/examples/chat-app)**: Complete WebSocket chat application with multiple rooms and authentication
- **[User Management](https://github.com/gabehamasaki/hikari-go/tree/main/examples/user-management)**: RESTful API with JWT authentication and role-based access control
- **[File Upload](https://github.com/gabehamasaki/hikari-go/tree/main/examples/file-upload)**: Complete file upload system with validation, storage, and serving
- **[Todo App](https://github.com/gabehamasaki/hikari-go/tree/main/examples/todo-app)**: Simple todo application demonstrating CRUD operations

Each example includes:
- Complete source code
- README with setup instructions
- Test files and documentation
- Production deployment considerations

## Testing Your Examples

All examples can be tested using the included HTTP files or by running:

```bash
# Clone the repository
git clone https://github.com/gabehamasaki/hikari-go.git
cd hikari-go/examples

# Run any example
cd chat-app
go run main.go

# Open another terminal and test
curl http://localhost:8080/api/rooms
```

These examples demonstrate the power and flexibility of Hikari v0.2.0's new features including WebSocket support, enhanced route groups, and advanced middleware system.
    })

    app.ListenAndServe()
}
```

## Advanced Examples

### Todo API

A complete REST API for managing todos:

```go
package main

import (
    "net/http"
    "strconv"
    "sync"
    "time"

    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

type Todo struct {
    ID          int       `json:"id"`
    Title       string    `json:"title"`
    Description string    `json:"description"`
    Completed   bool      `json:"completed"`
    CreatedAt   time.Time `json:"created_at"`
    UpdatedAt   time.Time `json:"updated_at"`
}

var (
    todos   = make(map[int]*Todo)
    todosMu sync.RWMutex
    nextID  = 1
)

func main() {
    app := hikari.New(":8080")

    // CORS middleware
    app.Use(func(c *hikari.Context) {
        c.SetHeader("Access-Control-Allow-Origin", "*")
        c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        c.SetHeader("Access-Control-Allow-Headers", "Content-Type")

        if c.Method() == "OPTIONS" {
            c.Status(http.StatusOK)
            return
        }
    })

    // API v1 group
    v1 := app.Group("/api/v1")
    {
        // Health check
        v1.GET("/health", func(c *hikari.Context) {
            c.JSON(http.StatusOK, hikari.H{
                "status": "healthy",
                "timestamp": time.Now(),
            })
        })

        // Todo routes
        todos := v1.Group("/todos")
        {
            todos.GET("/", listTodos)
            todos.POST("/", createTodo)
            todos.GET("/:id", getTodo)
            todos.PUT("/:id", updateTodo)
            todos.DELETE("/:id", deleteTodo)
        }
    }

    app.ListenAndServe()
}

func listTodos(c *hikari.Context) {
    todosMu.RLock()
    defer todosMu.RUnlock()

    status := c.Query("status")
    var result []*Todo

    for _, todo := range todos {
        if status == "" ||
           (status == "completed" && todo.Completed) ||
           (status == "pending" && !todo.Completed) {
            result = append(result, todo)
        }
    }

    c.JSON(http.StatusOK, hikari.H{
        "todos": result,
        "count": len(result),
    })
}

func createTodo(c *hikari.Context) {
    var req struct {
        Title       string `json:"title"`
        Description string `json:"description"`
    }

    if err := c.Bind(&req); err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid JSON format",
        })
        return
    }

    if req.Title == "" {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Title is required",
        })
        return
    }

    todosMu.Lock()
    defer todosMu.Unlock()

    todo := &Todo{
        ID:          nextID,
        Title:       req.Title,
        Description: req.Description,
        Completed:   false,
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }
    todos[nextID] = todo
    nextID++

    c.JSON(http.StatusCreated, hikari.H{
        "message": "Todo created successfully",
        "todo":    todo,
    })
}

func getTodo(c *hikari.Context) {
    id, err := strconv.Atoi(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid todo ID",
        })
        return
    }

    todosMu.RLock()
    todo, exists := todos[id]
    todosMu.RUnlock()

    if !exists {
        c.JSON(http.StatusNotFound, hikari.H{
            "error": "Todo not found",
        })
        return
    }

    c.JSON(http.StatusOK, hikari.H{
        "todo": todo,
    })
}

func updateTodo(c *hikari.Context) {
    id, err := strconv.Atoi(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid todo ID",
        })
        return
    }

    var req struct {
        Title       *string `json:"title"`
        Description *string `json:"description"`
        Completed   *bool   `json:"completed"`
    }

    if err := c.Bind(&req); err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid JSON format",
        })
        return
    }

    todosMu.Lock()
    defer todosMu.Unlock()

    todo, exists := todos[id]
    if !exists {
        c.JSON(http.StatusNotFound, hikari.H{
            "error": "Todo not found",
        })
        return
    }

    if req.Title != nil {
        todo.Title = *req.Title
    }
    if req.Description != nil {
        todo.Description = *req.Description
    }
    if req.Completed != nil {
        todo.Completed = *req.Completed
    }
    todo.UpdatedAt = time.Now()

    c.JSON(http.StatusOK, hikari.H{
        "message": "Todo updated successfully",
        "todo":    todo,
    })
}

func deleteTodo(c *hikari.Context) {
    id, err := strconv.Atoi(c.Param("id"))
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid todo ID",
        })
        return
    }

    todosMu.Lock()
    defer todosMu.Unlock()

    if _, exists := todos[id]; !exists {
        c.JSON(http.StatusNotFound, hikari.H{
            "error": "Todo not found",
        })
        return
    }

    delete(todos, id)
    c.JSON(http.StatusOK, hikari.H{
        "message": "Todo deleted successfully",
    })
}
```

### File Upload Server

Handle file uploads with validation:

```go
package main

import (
    "fmt"
    "io"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "time"

    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

const (
    maxFileSize   = 10 << 20 // 10 MB
    uploadDir     = "./uploads"
)

func main() {
    app := hikari.New(":8080")

    // Create uploads directory
    os.MkdirAll(uploadDir, 0755)

    // Serve upload form
    app.GET("/", func(c *hikari.Context) {
        html := `
<!DOCTYPE html>
<html>
<head>
    <title>File Upload</title>
</head>
<body>
    <h1>File Upload</h1>
    <form action="/upload" method="post" enctype="multipart/form-data">
        <input type="file" name="file" accept="image/*,application/pdf" required>
        <br><br>
        <input type="submit" value="Upload File">
    </form>
</body>
</html>`
        c.SetHeader("Content-Type", "text/html")
        c.String(http.StatusOK, html)
    })

    // Handle file upload
    app.POST("/upload", uploadFile)

    // Serve uploaded files
    app.GET("/uploads/*", func(c *hikari.Context) {
        filepath := c.Wildcard()
        c.File(uploadDir + "/" + filepath)
    })

    app.ListenAndServe()
}

func uploadFile(c *hikari.Context) {
    // Parse multipart form with size limit
    err := c.Request.ParseMultipartForm(maxFileSize)
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "File too large or invalid form data",
        })
        return
    }

    file, header, err := c.Request.FormFile("file")
    if err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "No file uploaded",
        })
        return
    }
    defer file.Close()

    // Validate file type
    if !isValidFileType(header.Filename) {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid file type. Only images and PDFs allowed",
        })
        return
    }

    // Generate unique filename
    ext := filepath.Ext(header.Filename)
    filename := fmt.Sprintf("file_%d%s", time.Now().UnixNano(), ext)
    dst := filepath.Join(uploadDir, filename)

    // Create destination file
    out, err := os.Create(dst)
    if err != nil {
        c.JSON(http.StatusInternalServerError, hikari.H{
            "error": "Failed to create file",
        })
        return
    }
    defer out.Close()

    // Copy uploaded file to destination
    _, err = io.Copy(out, file)
    if err != nil {
        c.JSON(http.StatusInternalServerError, hikari.H{
            "error": "Failed to save file",
        })
        return
    }

    c.JSON(http.StatusCreated, hikari.H{
        "message": "File uploaded successfully",
        "filename": filename,
        "original_name": header.Filename,
        "size": header.Size,
        "url": fmt.Sprintf("/uploads/%s", filename),
    })
}

func isValidFileType(filename string) bool {
    ext := strings.ToLower(filepath.Ext(filename))
    validExtensions := []string{".jpg", ".jpeg", ".png", ".gif", ".webp", ".pdf"}

    for _, validExt := range validExtensions {
        if ext == validExt {
            return true
        }
    }
    return false
}
```

### User Management with Authentication

Complete user management system with JWT authentication:

```go
package main

import (
    "crypto/rand"
    "encoding/hex"
    "net/http"
    "strconv"
    "sync"
    "time"

    "github.com/gabehamasaki/hikari-go/pkg/hikari"
    "golang.org/x/crypto/bcrypt"
)

type User struct {
    ID        int       `json:"id"`
    Username  string    `json:"username"`
    Email     string    `json:"email"`
    Password  string    `json:"-"` // Never return password in JSON
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type Session struct {
    Token     string    `json:"token"`
    UserID    int       `json:"user_id"`
    ExpiresAt time.Time `json:"expires_at"`
}

var (
    users     = make(map[int]*User)
    usersMu   sync.RWMutex
    sessions  = make(map[string]*Session)
    sessionsMu sync.RWMutex
    nextUserID = 1
)

func main() {
    app := hikari.New(":8080")

    // CORS middleware
    app.Use(corsMiddleware)

    // API routes
    api := app.Group("/api/v1")
    {
        // Public routes
        api.POST("/register", registerUser)
        api.POST("/login", loginUser)

        // Protected routes
        protected := api.Group("", authMiddleware)
        {
            protected.GET("/profile", getProfile)
            protected.PUT("/profile", updateProfile)
            protected.POST("/logout", logoutUser)
            protected.GET("/users", listUsers)
        }
    }

    app.ListenAndServe()
}

func corsMiddleware(c *hikari.Context) {
    c.SetHeader("Access-Control-Allow-Origin", "*")
    c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
    c.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

    if c.Method() == "OPTIONS" {
        c.Status(http.StatusOK)
        return
    }
}

func authMiddleware(c *hikari.Context) {
    token := c.GetHeader("Authorization")
    if token == "" {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Authorization token required",
        })
        return
    }

    // Remove "Bearer " prefix if present
    if len(token) > 7 && token[:7] == "Bearer " {
        token = token[7:]
    }

    sessionsMu.RLock()
    session, exists := sessions[token]
    sessionsMu.RUnlock()

    if !exists || time.Now().After(session.ExpiresAt) {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Invalid or expired token",
        })
        return
    }

    c.Set("user_id", session.UserID)
}

func registerUser(c *hikari.Context) {
    var req struct {
        Username string `json:"username"`
        Email    string `json:"email"`
        Password string `json:"password"`
    }

    if err := c.Bind(&req); err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid JSON format",
        })
        return
    }

    // Validate input
    if req.Username == "" || req.Email == "" || req.Password == "" {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Username, email, and password are required",
        })
        return
    }

    if len(req.Password) < 6 {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Password must be at least 6 characters",
        })
        return
    }

    // Hash password
    hashedPassword, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
    if err != nil {
        c.JSON(http.StatusInternalServerError, hikari.H{
            "error": "Failed to hash password",
        })
        return
    }

    usersMu.Lock()
    defer usersMu.Unlock()

    // Check if username already exists
    for _, user := range users {
        if user.Username == req.Username {
            c.JSON(http.StatusConflict, hikari.H{
                "error": "Username already exists",
            })
            return
        }
        if user.Email == req.Email {
            c.JSON(http.StatusConflict, hikari.H{
                "error": "Email already exists",
            })
            return
        }
    }

    user := &User{
        ID:        nextUserID,
        Username:  req.Username,
        Email:     req.Email,
        Password:  string(hashedPassword),
        CreatedAt: time.Now(),
        UpdatedAt: time.Now(),
    }
    users[nextUserID] = user
    nextUserID++

    c.JSON(http.StatusCreated, hikari.H{
        "message": "User registered successfully",
        "user":    user,
    })
}

func loginUser(c *hikari.Context) {
    var req struct {
        Username string `json:"username"`
        Password string `json:"password"`
    }

    if err := c.Bind(&req); err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid JSON format",
        })
        return
    }

    usersMu.RLock()
    var user *User
    for _, u := range users {
        if u.Username == req.Username {
            user = u
            break
        }
    }
    usersMu.RUnlock()

    if user == nil {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Invalid credentials",
        })
        return
    }

    if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(req.Password)); err != nil {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Invalid credentials",
        })
        return
    }

    // Generate session token
    token, err := generateToken()
    if err != nil {
        c.JSON(http.StatusInternalServerError, hikari.H{
            "error": "Failed to generate token",
        })
        return
    }

    session := &Session{
        Token:     token,
        UserID:    user.ID,
        ExpiresAt: time.Now().Add(24 * time.Hour),
    }

    sessionsMu.Lock()
    sessions[token] = session
    sessionsMu.Unlock()

    c.JSON(http.StatusOK, hikari.H{
        "message": "Login successful",
        "token":   token,
        "user":    user,
        "expires_at": session.ExpiresAt,
    })
}

func getProfile(c *hikari.Context) {
    userID := c.GetInt("user_id")

    usersMu.RLock()
    user, exists := users[userID]
    usersMu.RUnlock()

    if !exists {
        c.JSON(http.StatusNotFound, hikari.H{
            "error": "User not found",
        })
        return
    }

    c.JSON(http.StatusOK, hikari.H{
        "user": user,
    })
}

func updateProfile(c *hikari.Context) {
    userID := c.GetInt("user_id")

    var req struct {
        Email *string `json:"email"`
    }

    if err := c.Bind(&req); err != nil {
        c.JSON(http.StatusBadRequest, hikari.H{
            "error": "Invalid JSON format",
        })
        return
    }

    usersMu.Lock()
    defer usersMu.Unlock()

    user, exists := users[userID]
    if !exists {
        c.JSON(http.StatusNotFound, hikari.H{
            "error": "User not found",
        })
        return
    }

    if req.Email != nil {
        user.Email = *req.Email
        user.UpdatedAt = time.Now()
    }

    c.JSON(http.StatusOK, hikari.H{
        "message": "Profile updated successfully",
        "user":    user,
    })
}

func listUsers(c *hikari.Context) {
    usersMu.RLock()
    defer usersMu.RUnlock()

    var userList []*User
    for _, user := range users {
        userList = append(userList, user)
    }

    c.JSON(http.StatusOK, hikari.H{
        "users": userList,
        "count": len(userList),
    })
}

func logoutUser(c *hikari.Context) {
    token := c.GetHeader("Authorization")
    if len(token) > 7 && token[:7] == "Bearer " {
        token = token[7:]
    }

    sessionsMu.Lock()
    delete(sessions, token)
    sessionsMu.Unlock()

    c.JSON(http.StatusOK, hikari.H{
        "message": "Logged out successfully",
    })
}

func generateToken() (string, error) {
    bytes := make([]byte, 32)
    if _, err := rand.Read(bytes); err != nil {
        return "", err
    }
    return hex.EncodeToString(bytes), nil
}
```

## Running the Examples

All examples can be run with:

```bash
go mod init example
go get github.com/gabehamasaki/hikari-go
go run main.go
```

Then visit `http://localhost:8080` in your browser or test with curl:

```bash
# Test the Todo API
curl -X GET http://localhost:8080/api/v1/todos

# Create a new todo
curl -X POST http://localhost:8080/api/v1/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Learn Hikari", "description": "Build awesome APIs"}'
```
