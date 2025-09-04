---
sidebar_position: 5
---

# Examples

Practical examples demonstrating Hikari's features and best practices.

## Basic Examples

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
        c.String(http.StatusOK, "Hello, World!")
    })

    app.ListenAndServe()
}
```

### JSON API

```go
package main

import (
    "net/http"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    app.GET("/api/status", func(c *hikari.Context) {
        c.JSON(http.StatusOK, hikari.H{
            "status": "online",
            "service": "my-api",
            "version": "1.0.0",
        })
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
