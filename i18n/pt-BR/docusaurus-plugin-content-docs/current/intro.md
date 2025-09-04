# Começando

**Hikari** (光 - "luz" em japonês) é um framework web HTTP leve, rápido e elegante para Go. Ele fornece uma base minimalista, mas poderosa, para construir aplicações web modernas e APIs com logging integrado, recuperação e capacidades de desligamento gracioso.

## ✨ Recursos

- 🚀 **Leve e Rápido** - Overhead mínimo com performance máxima
- 🛡️ **Recuperação Integrada** - Recuperação automática de pânico para evitar crashes
- 📝 **Logging Estruturado** - Logs coloridos bonitos com o logger Zap da Uber
- 🏗️ **Grupos de Rota** - Organize rotas com prefixos e middleware compartilhados
- 🔗 **Parâmetros de Rota** - Suporte para parâmetros de rota dinâmicos (`:param`) e wildcards (`*`)
- 🧩 **Suporte a Middleware** - Sistema extensível de middleware (global, grupo e por rota)
- 🎯 **Baseado em Contexto** - Contexto rico com binding JSON, query params, armazenamento e interface de contexto Go
- 🛑 **Desligamento Gracioso** - Manipulação adequada de desligamento do servidor com sinais
- 📊 **Logging de Requisições** - Logging automático contextual com timing e User-Agent
- 📁 **Servidor de Arquivos** - Servir arquivos estáticos facilmente
- ⚙️ **Timeouts Configurados** - Timeouts de leitura e escrita pré-configurados (5s) e timeouts de requisição configuráveis
- 💾 **Armazenamento de Contexto** - Sistema integrado de armazenamento chave-valor com acesso thread-safe
- ⏱️ **Gerenciamento de Contexto** - Suporte completo à interface context.Context do Go com cancelamento e timeouts
- 🔄 **Normalização de Padrões** - Limpeza e validação automática de padrões de rota
- 🎯 **Versionamento de API** - Suporte integrado para estruturas organizadas de API

## 🚀 Instalação

Crie um novo módulo Go e instale o Hikari:

```bash
go mod init seu-projeto
go get github.com/gabehamasaki/hikari-go
```

## 🎯 Exemplo Rápido

Aqui está um exemplo simples para começar:

```go
package main

import (
    "net/http"
    "github.com/gabehamasaki/hikari-go/pkg/hikari"
)

func main() {
    app := hikari.New(":8080")

    // Grupo API v1
    v1Group := app.Group("/api/v1")
    {
        v1Group.GET("/hello/:name", func(c *hikari.Context) {
            c.JSON(http.StatusOK, hikari.H{
                "message": "Olá, " + c.Param("name") + "!",
                "status":  "success",
            })
        })

        // Health check
        v1Group.GET("/health", func(c *hikari.Context) {
            c.JSON(http.StatusOK, hikari.H{
                "status": "healthy",
                "service": "minha-api",
            })
        })
    }

    app.ListenAndServe()
}
```

Execute sua aplicação:

```bash
go run main.go
```

Visite `http://localhost:8080/api/v1/hello/mundo` para ver sua app em ação!

## 🏗️ Próximos Passos

- Aprenda sobre [roteamento e middleware](./routing)
- Explore a [referência da API](./api)
- Confira [exemplos práticos](./examples)
- Entenda o [gerenciamento de contexto](./context)
