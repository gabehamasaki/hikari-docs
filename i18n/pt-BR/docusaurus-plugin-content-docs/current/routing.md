# Roteamento e Middleware

O Hikari fornece um sistema de roteamento poderoso e flexível com suporte para métodos HTTP, parâmetros de rota, wildcards e middleware.

## Métodos HTTP

O Hikari suporta todos os métodos HTTP padrão:

```go
app := hikari.New(":8080")

app.GET("/usuarios", listarUsuarios)
app.POST("/usuarios", criarUsuario)
app.PUT("/usuarios/:id", atualizarUsuario)
app.PATCH("/usuarios/:id", patchUsuario)
app.DELETE("/usuarios/:id", deletarUsuario)
```

## Parâmetros de Rota

### Parâmetros Dinâmicos

Use a sintaxe `:param` para segmentos de rota dinâmicos:

```go
app.GET("/usuarios/:id", func(c *hikari.Context) {
    userID := c.Param("id")
    c.JSON(http.StatusOK, hikari.H{
        "user_id": userID,
    })
})

app.GET("/posts/:categoria/:id", func(c *hikari.Context) {
    categoria := c.Param("categoria")
    postID := c.Param("id")
    c.JSON(http.StatusOK, hikari.H{
        "categoria": categoria,
        "post_id": postID,
    })
})
```

### Parâmetros Wildcard

Use `*` para correspondência wildcard:

```go
app.GET("/arquivos/*", func(c *hikari.Context) {
    caminhoArquivo := c.Wildcard()
    c.String(http.StatusOK, "Caminho do arquivo: %s", caminhoArquivo)
})
```

## Grupos de Rota

Organize rotas relacionadas com prefixos e middleware compartilhados:

```go
// Grupo API v1
v1 := app.Group("/api/v1")
{
    // Rotas de usuários
    usuarios := v1.Group("/usuarios")
    {
        usuarios.GET("/", listarUsuarios)
        usuarios.POST("/", criarUsuario)
        usuarios.GET("/:id", obterUsuario)
        usuarios.PUT("/:id", atualizarUsuario)
        usuarios.DELETE("/:id", deletarUsuario)
    }

    // Rotas de posts
    posts := v1.Group("/posts")
    {
        posts.GET("/", listarPosts)
        posts.POST("/", criarPost)
        posts.GET("/:id", obterPost)
    }
}

// Grupo API v2
v2 := app.Group("/api/v2")
{
    v2.GET("/usuarios", listarUsuariosV2)
}
```

## Middleware

O Hikari suporta três níveis de middleware: global, nível de grupo e nível de rota.

### Middleware Global

Aplicado a todas as rotas:

```go
app := hikari.New(":8080")

// Middleware global
app.Use(corsMiddleware)
app.Use(loggingMiddleware)
```

### Middleware de Grupo

Aplicado a todas as rotas dentro de um grupo:

```go
// Rotas de API protegidas
api := app.Group("/api", authMiddleware, rateLimitMiddleware)
{
    api.GET("/perfil", obterPerfil)
    api.POST("/posts", criarPost)
}
```

### Middleware de Nível de Rota

Aplicado a rotas específicas:

```go
// Múltiplos middleware em uma única rota
app.POST("/admin/usuarios",
    criarUsuarioHandler,
    authMiddleware,
    adminMiddleware,
    auditMiddleware,
)
```

## Exemplos de Middleware

### Middleware CORS

```go
func corsMiddleware(c *hikari.Context) {
    c.SetHeader("Access-Control-Allow-Origin", "*")
    c.SetHeader("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE")
    c.SetHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
}
```

### Middleware de Autenticação

```go
func authMiddleware(c *hikari.Context) {
    token := c.GetHeader("Authorization")
    if token == "" {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Header Authorization obrigatório",
        })
        return
    }

    // Validar token e definir contexto do usuário
    userID, err := validarToken(token)
    if err != nil {
        c.JSON(http.StatusUnauthorized, hikari.H{
            "error": "Token inválido",
        })
        return
    }

    c.Set("user_id", userID)
}
```

### Middleware de Rate Limiting

```go
func rateLimitMiddleware(c *hikari.Context) {
    // Implementar lógica de rate limiting
    clientIP := c.Request.RemoteAddr
    if isRateLimited(clientIP) {
        c.JSON(http.StatusTooManyRequests, hikari.H{
            "error": "Limite de taxa excedido",
        })
        return
    }
}
```

## Servindo Arquivos

Sirva arquivos estáticos usando rotas wildcard e o método File:

```go
// Servir arquivos do diretório ./static
app.GET("/static/*", func(c *hikari.Context) {
    caminhoArquivo := c.Wildcard()
    c.File("./static/" + caminhoArquivo)
})

// Servir um único arquivo
app.GET("/favicon.ico", func(c *hikari.Context) {
    c.File("./static/favicon.ico")
})
```

## Normalização de Padrões de Rota

O Hikari normaliza automaticamente os padrões de rota:

```go
// Estes são equivalentes:
app.GET("/usuarios/", handler)     // Normalizado para "/usuarios"
app.GET("/usuarios", handler)

app.GET("//api//v1//usuarios//", handler)  // Normalizado para "/api/v1/usuarios"
```
