#### CRM AI RESEACH

Deployment of local crm with AI integration

![](https://raw.githubusercontent.com/AllanMogley/20-local-crm-ai-research/refs/heads/main/.assets/CRM%20Research.png)



#### Quick  Setup Guide

Clone repository

```
git clone --depth 1 https://github.com/AllanMogley/20-local-crm-ai-research.git
cd 20-local-crm-ai-research/.docker
docker compose up -d
```

##### Open WebUI : accessed via web browser

```
localhost:8080
```

##### Ollama : Serves models

```
docker compose exec -ti ollama bash
```

```
ollama pull qwen3.5:9b
```
