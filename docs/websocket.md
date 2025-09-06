---
sidebar_position: 5
---

# WebSocket Support

Hikari v0.2.0 introduz suporte completo para WebSocket, permitindo comunicação bidirecional em tempo real entre cliente e servidor. O sistema é baseado na arquitetura de **Hubs** que organiza conexões por tópicos ou salas.

## ✨ Principais Funcionalidades

- **🏗️ Arquitetura Multi-Hub**: Organize conexões em salas independentes
- **📡 Broadcasting**: Envie mensagens para todas as conexões de um hub
- **💬 Mensagens Diretas**: Comunique-se com conexões específicas
- **🔒 Middleware Support**: Sistema de middleware para rotas WebSocket
- **⚙️ Configuração Flexível**: Buffers, timeouts e compressão configuráveis
- **🔄 Keepalive**: Sistema automático de ping/pong
- **🧹 Cleanup Automático**: Gerenciamento do ciclo de vida das conexões

## 🚀 Configuração Básica

### Inicializando WebSocket

```go
package main

import (
    "net/http"
    "time"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    // Configurar WebSocket (opcional - usa configuração padrão se omitido)
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

    // Registrar rota WebSocket
    app.WebSocket("/ws/chat", "chat_room", chatHandler)

    app.ListenAndServe()
}
```

### Handler WebSocket

```go
func chatHandler(c *hikari.WSContext) {
    if c.IsTextMessage() {
        // Obter mensagem como string
        message := c.GetMessage()

        // Enviar de volta para o cliente
        c.Send([]byte("Echo: " + message))

        // Ou broadcast para todos no hub
        c.Broadcast([]byte("Broadcast: " + message))
    }
}
```

## 🎯 WebSocket Context

O `WSContext` estende o contexto padrão com métodos específicos para WebSocket:

### Métodos de Envio

```go
func chatHandler(c *hikari.WSContext) {
    // Enviar bytes brutos
    c.Send([]byte("Mensagem simples"))

    // Enviar JSON
    response := map[string]string{"type": "message", "text": "Olá!"}
    c.JSON(response)

    // Enviar string
    c.String("Mensagem de texto")

    // Broadcast para todos no hub
    c.Broadcast([]byte("Mensagem para todos"))
    c.BroadcastJSON(map[string]string{"event": "user_joined"})

    // Enviar para conexão específica
    c.SendToConnection("conn_id_123", []byte("Mensagem privada"))
}
```

### Métodos de Recebimento

```go
func chatHandler(c *hikari.WSContext) {
    // Verificar tipo de mensagem
    if c.IsTextMessage() {
        message := c.GetMessage()
        // Processar mensagem de texto
    } else if c.IsBinaryMessage() {
        data := c.GetBinaryMessage()
        // Processar dados binários
    }

    // Bind JSON para struct
    var msg ChatMessage
    if err := c.Bind(&msg); err == nil {
        // Processar mensagem estruturada
    }
}
```

### Informações da Conexão

```go
func chatHandler(c *hikari.WSContext) {
    // ID único da conexão
    connectionID := c.ConnectionID()

    // Nome do hub
    hubName := c.HubName()

    // Request HTTP original
    request := c.Request()

    // Headers da requisição
    userAgent := request.Header.Get("User-Agent")
}
```

## 🏗️ Sistema de Hubs

Os hubs organizam conexões relacionadas e permitem broadcasting eficiente:

### Múltiplos Hubs

```go
func main() {
    app := hikari.New(":8080")
    app.WithWebSocket(hikari.DefaultWebSocketConfig())

    // Chat geral
    app.WebSocket("/ws/general", "general", generalChatHandler)

    // Chat de tecnologia
    app.WebSocket("/ws/tech", "tech", techChatHandler)

    // Sala VIP com middleware de autenticação
    app.WebSocket("/ws/vip", "vip", vipChatHandler, authMiddleware)

    app.ListenAndServe()
}
```

### Acesso a Hubs via HTTP

```go
// Endpoint HTTP para enviar mensagem para um hub
app.POST("/api/chat/:room/message", func(c *hikari.Context) {
    roomName := c.Param("room")

    if hub, exists := app.GetWebSocketHub(roomName); exists {
        message := []byte("Mensagem via API")
        hub.Broadcast(message)
        c.JSON(http.StatusOK, hikari.H{"status": "sent"})
    } else {
        c.JSON(http.StatusNotFound, hikari.H{"error": "Room not found"})
    }
})
```

## 🛡️ Middleware para WebSocket

Os middlewares funcionam normalmente com rotas WebSocket:

```go
func authMiddleware(next hikari.HandlerFunc) hikari.HandlerFunc {
    return func(c *hikari.Context) {
        token := c.Query("token")
        if token != "valid_token" {
            c.JSON(401, hikari.H{"error": "Invalid token"})
            return
        }
        c.Set("authenticated", true)
        next(c)
    }
}

// Aplicar middleware
app.WebSocket("/ws/private", "private", privateHandler, authMiddleware)
```

## ⚙️ Configuração Avançada

### Configuração Completa

```go
wsConfig := &hikari.WebSocketConfig{
    ReadBufferSize:    1024,            // Buffer de leitura (bytes)
    WriteBufferSize:   1024,            // Buffer de escrita (bytes)
    HandshakeTimeout:  10 * time.Second, // Timeout do handshake
    CheckOrigin: func(r *http.Request) bool { // Validação CORS
        origin := r.Header.Get("Origin")
        return origin == "https://meusite.com"
    },
    EnableCompression: true,             // Compressão de mensagens
    PingInterval:      30 * time.Second, // Intervalo de ping
    PongTimeout:       60 * time.Second, // Timeout para pong
    RegisterTimeout:   30 * time.Second, // Timeout para registro
}
```

### Configuração Padrão

```go
// Usa configuração padrão otimizada
app.WithWebSocket(hikari.DefaultWebSocketConfig())

// Ou simplesmente omitir configuração
app.WithWebSocket(nil)
```

## 📡 Exemplo Completo: Chat Multi-Salas

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
    Room     string `json:"room,omitempty"`
}

func main() {
    app := hikari.New(":8080")

    // Configurar WebSocket
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

    // Salas de chat
    app.WebSocket("/ws/general", "general", chatHandler)
    app.WebSocket("/ws/tech", "tech", chatHandler)
    app.WebSocket("/ws/random", "random", chatHandler)

    // Sala VIP com autenticação
    app.WebSocket("/ws/vip", "vip", chatHandler, vipAuthMiddleware)

    // API para listar salas
    app.GET("/api/rooms", func(c *hikari.Context) {
        c.JSON(http.StatusOK, hikari.H{
            "rooms": []string{"general", "tech", "random", "vip"},
        })
    })

    // API para estatísticas da sala
    app.GET("/api/rooms/:room/stats", func(c *hikari.Context) {
        roomName := c.Param("room")
        if hub, exists := app.GetWebSocketHub(roomName); exists {
            // Note: hub.ConnectionCount() seria uma funcionalidade futura
            c.JSON(http.StatusOK, hikari.H{
                "room": roomName,
                "status": "active",
            })
        } else {
            c.JSON(http.StatusNotFound, hikari.H{"error": "Room not found"})
        }
    })

    // Servir arquivos estáticos
    app.GET("/static/*", func(c *hikari.Context) {
        c.File("./static/" + c.Wildcard())
    })

    app.ListenAndServe()
}

func chatHandler(c *hikari.WSContext) {
    if c.IsTextMessage() {
        var msg ChatMessage
        if err := c.Bind(&msg); err == nil {
            switch msg.Type {
            case "join":
                joinMessage := ChatMessage{
                    Type:     "user_joined",
                    Username: msg.Username,
                    Message:  msg.Username + " entrou na sala",
                }
                c.BroadcastJSON(joinMessage)

            case "message":
                // Rebroadcast a mensagem
                c.BroadcastJSON(msg)

            case "leave":
                leaveMessage := ChatMessage{
                    Type:     "user_left",
                    Username: msg.Username,
                    Message:  msg.Username + " saiu da sala",
                }
                c.BroadcastJSON(leaveMessage)
            }
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
```

## 🌐 Cliente JavaScript

```javascript
const ws = new WebSocket('ws://localhost:8080/ws/general');

ws.onopen = () => {
    ws.send(JSON.stringify({
        type: 'join',
        username: 'João',
        message: 'entrou na sala'
    }));
};

ws.onmessage = (event) => {
    const message = JSON.parse(event.data);
    console.log('Mensagem recebida:', message);
};

// Enviar mensagem
function sendMessage(text) {
    ws.send(JSON.stringify({
        type: 'message',
        username: 'João',
        message: text
    }));
}
```

## 🚀 Próximos Passos

- Explore o [exemplo completo de chat](https://github.com/gabehamasaki/hikari-go/tree/main/examples/chat-app)
- Veja mais [exemplos práticos](./examples)
- Consulte a [referência da API](./api)
