# Atividade Prática: Banco de Dados + API + Front-end

Oct 22, 2026 · @guilherme

## Apresentação

Você vai construir o sistema **EventoSENAI**, uma agenda de eventos escolares em que alunos se inscrevem em palestras, oficinas e workshops. O sistema tem três camadas que conversam entre si: banco de dados MySQL, API REST em Node.js/Express e um front-end em Next.js.

O objetivo não é só ter cada parte funcionando, e sim ver um dado sair do formulário, passar pela API e ficar gravado no banco.

| Item | Detalhe |
| --- | --- |
| Modalidade | Dupla |
| Tecnologias | MySQL 8, Node.js 20+, Express, mysql2, cors, Next.js (React) |
| Ferramentas | MySQL Workbench, VS Code, Thunder Client ou Postman |
| Entrega | Repositório no GitHub com `/database`, `/api` e `/front` + README |

**Competências trabalhadas**

- Modelar um banco relacional com chaves primárias, estrangeiras e relacionamento N:N
- Criar rotas REST com os verbos e códigos HTTP corretos
- Conectar a API ao banco com consultas parametrizadas (proteção contra SQL Injection)
- Consumir a API em componentes Next.js com `fetch` e tratar erros

**Estrutura de pastas esperada**

```
eventosenai/
├── database/
│   └── script.sql
├── api/
│   ├── src/
│   │   ├── db.js
│   │   ├── server.js
│   │   └── routes/
│   │       ├── eventos.js
│   │       ├── participantes.js
│   │       └── inscricoes.js
│   ├── .env
│   └── package.json
└── front/                  (projeto Next.js)
    ├── app/
    │   ├── layout.js
    │   ├── page.js
    │   └── globals.css
    ├── components/
    │   ├── EventoCard.js
    │   ├── FormParticipante.js
    │   └── FormInscricao.js
    ├── lib/
    │   └── api.js
    ├── .env.local
    └── package.json
```

## Etapa 1 — Banco de dados

O banco tem quatro tabelas: um evento pertence a uma categoria, e participantes e eventos se ligam pela tabela `inscricoes` (relacionamento N:N).

| Tabela | Campos principais | Regras |
| --- | --- | --- |
| categorias | id, nome | nome único |
| eventos | id, titulo, descricao, data\_evento, local, vagas, categoria\_id | vagas > 0; FK para categorias |
| participantes | id, nome, email, turma | e-mail único |
| inscricoes | id, evento\_id, participante\_id, data\_inscricao | um participante só se inscreve uma vez por evento |

**Tarefas**

1. Desenhe o DER (Workbench, draw.io ou papel) antes de escrever o SQL.
2. Crie o `database/script.sql` com o banco, as tabelas e as chaves.
3. Insira pelo menos 3 categorias, 5 eventos e 5 participantes.
4. Escreva e teste as consultas da lista abaixo.

**Script base** (complete o que falta)

```sql
CREATE DATABASE IF NOT EXISTS eventosenai;
USE eventosenai;

CREATE TABLE categorias (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nome VARCHAR(60) NOT NULL UNIQUE
);

CREATE TABLE eventos (
  id INT AUTO_INCREMENT PRIMARY KEY,
  titulo VARCHAR(120) NOT NULL,
  descricao TEXT,
  data_evento DATETIME NOT NULL,
  local VARCHAR(100) NOT NULL,
  vagas INT NOT NULL CHECK (vagas > 0),
  categoria_id INT NOT NULL,
  FOREIGN KEY (categoria_id) REFERENCES categorias(id)
);

-- TODO: crie a tabela participantes (e-mail único)

CREATE TABLE inscricoes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  evento_id INT NOT NULL,
  participante_id INT NOT NULL,
  data_inscricao DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE (evento_id, participante_id),
  FOREIGN KEY (evento_id) REFERENCES eventos(id) ON DELETE CASCADE,
  FOREIGN KEY (participante_id) REFERENCES participantes(id) ON DELETE CASCADE
);

INSERT INTO categorias (nome) VALUES ('Palestra'), ('Oficina'), ('Workshop');
-- TODO: insira eventos e participantes
```

**Consultas para testar no Workbench** (elas viram rotas da API na etapa 2)

- Listar eventos com o nome da categoria (`JOIN`)
- Listar os participantes inscritos em um evento
- Mostrar cada evento com o total de inscritos e as vagas restantes (`LEFT JOIN` + `COUNT` + `GROUP BY`)
- Tentar inscrever o mesmo participante duas vezes e anotar o erro que o MySQL devolve

## Etapa 2 — API REST

A API é a única parte que fala com o banco: o front nunca acessa o MySQL diretamente.

**Preparando o projeto**

```bash
cd api
npm init -y
npm install express mysql2 cors dotenv
npm install -D nodemon
```

No `package.json`, adicione o script `"dev": "nodemon src/server.js"`.

**Arquivo `.env`** (nunca suba este arquivo para o GitHub; crie um `.gitignore`)

```
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=senai
DB_NAME=eventosenai
PORT=3333
```

**Conexão com o banco — `src/db.js`**

```js
require('dotenv').config();
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  waitForConnections: true,
  connectionLimit: 10
});

module.exports = pool;
```

**Servidor — `src/server.js`**

```js
require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/eventos', require('./routes/eventos'));
app.use('/participantes', require('./routes/participantes'));
app.use('/inscricoes', require('./routes/inscricoes'));

app.listen(process.env.PORT, () =>
  console.log(`API rodando em http://localhost:${process.env.PORT}`)
);
```

**Exemplo de rota — `src/routes/eventos.js`** (use como modelo para as outras)

```js
const router = require('express').Router();
const db = require('../db');

// GET /eventos -> lista eventos com categoria e vagas restantes
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT e.id, e.titulo, e.data_evento, e.local, e.vagas,
             c.nome AS categoria,
             e.vagas - COUNT(i.id) AS vagas_restantes
      FROM eventos e
      JOIN categorias c ON c.id = e.categoria_id
      LEFT JOIN inscricoes i ON i.evento_id = e.id
      GROUP BY e.id
      ORDER BY e.data_evento`);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ erro: 'Erro ao buscar eventos' });
  }
});

// POST /eventos -> cria um evento
router.post('/', async (req, res) => {
  const { titulo, descricao, data_evento, local, vagas, categoria_id } = req.body;
  if (!titulo || !data_evento || !local || !vagas || !categoria_id) {
    return res.status(400).json({ erro: 'Campos obrigatórios faltando' });
  }
  try {
    const [result] = await db.query(
      'INSERT INTO eventos (titulo, descricao, data_evento, local, vagas, categoria_id) VALUES (?, ?, ?, ?, ?, ?)',
      [titulo, descricao, data_evento, local, vagas, categoria_id]
    );
    res.status(201).json({ id: result.insertId });
  } catch (err) {
    res.status(500).json({ erro: 'Erro ao criar evento' });
  }
});

// TODO: GET /:id, PUT /:id, DELETE /:id

module.exports = router;
```

> Atenção: sempre use `?` nos valores da consulta. Montar o SQL concatenando texto (`'... WHERE id = ' + id`) abre a porta para SQL Injection.

**Rotas que a API deve ter**

| Método | Rota | O que faz | Sucesso | Erros esperados |
| --- | --- | --- | --- | --- |
| GET | /eventos | Lista eventos com categoria e vagas restantes | 200 | 500 |
| GET | /eventos/:id | Detalha um evento | 200 | 404 |
| POST | /eventos | Cria evento | 201 | 400 |
| PUT | /eventos/:id | Atualiza evento | 200 | 400, 404 |
| DELETE | /eventos/:id | Remove evento | 204 | 404 |
| GET | /participantes | Lista participantes | 200 | 500 |
| POST | /participantes | Cadastra participante | 201 | 400, 409 (e-mail repetido) |
| GET | /eventos/:id/inscritos | Lista inscritos do evento | 200 | 404 |
| POST | /inscricoes | Inscreve participante em evento | 201 | 400, 409 (já inscrito ou sem vagas) |
| DELETE | /inscricoes/:id | Cancela inscrição | 204 | 404 |

**Regra de negócio obrigatória:** antes de inserir em `inscricoes`, a API confere se ainda há vagas. Sem vagas, devolve `409` com `{ "erro": "Evento lotado" }`.

**Teste antes de seguir:** monte uma coleção no Thunder Client ou Postman com uma requisição para cada rota e exporte o arquivo para a pasta `api/`.

## Etapa 3 — Front-end em Next.js

O front é um projeto Next.js (App Router) que busca e envia dados para a API com `fetch`. O Next roda na porta 3000 e a API na 3333, por isso as duas precisam estar no ar ao mesmo tempo.

**Criando o projeto**

```bash
npx create-next-app@latest front
cd front
npm run dev
```

Nas perguntas do instalador: TypeScript **No**, ESLint **Yes**, Tailwind opcional, pasta `src/` **No**, App Router **Yes**, alias de importação padrão (`@/*`).

**Arquivo `front/.env.local`**

```
NEXT_PUBLIC_API_URL=http://localhost:3333
```

> Só variáveis com o prefixo `NEXT_PUBLIC_` chegam ao navegador. Depois de criar ou alterar o `.env.local`, reinicie o `npm run dev`.

**A página deve ter**

1. Uma lista de eventos em cards (componente `EventoCard`): título, categoria, data formatada (dd/mm/aaaa hh:mm), local e vagas restantes.
2. Um botão "Ver inscritos" em cada card, que mostra os nomes dos inscritos.
3. Um formulário de cadastro de participante (componente `FormParticipante`: nome, e-mail, turma).
4. Um formulário de inscrição (componente `FormInscricao`) com dois `<select>`: evento e participante, preenchidos pela API.
5. Mensagens de sucesso e erro visíveis na tela, guardadas em estado (`useState`).
6. Card com aviso "Lotado" e botão desabilitado quando as vagas acabarem.

**Funções de acesso à API — `lib/api.js`**

```js
const API = process.env.NEXT_PUBLIC_API_URL;

export async function getEventos() {
  const resposta = await fetch(`${API}/eventos`, { cache: 'no-store' });
  if (!resposta.ok) throw new Error('Erro ao buscar eventos');
  return resposta.json();
}

export async function inscrever(evento_id, participante_id) {
  const resposta = await fetch(`${API}/inscricoes`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ evento_id, participante_id })
  });
  const dados = await resposta.json();
  return { ok: resposta.ok, dados };
}

// TODO: getParticipantes, cadastrarParticipante, getInscritos
```

**Card de evento — `components/EventoCard.js`**

```jsx
export default function EventoCard({ evento }) {
  const lotado = evento.vagas_restantes <= 0;

  return (
    <article className="card">
      <h3>{evento.titulo}</h3>
      <span className="tag">{evento.categoria}</span>
      <p>
        {new Date(evento.data_evento).toLocaleString('pt-BR')} · {evento.local}
      </p>
      <p>
        {lotado ? <strong>Lotado</strong> : <>Vagas restantes: <strong>{evento.vagas_restantes}</strong></>}
      </p>
    </article>
  );
}
```

**Página principal — `app/page.js`**

```jsx
'use client';

import { useEffect, useState } from 'react';
import { getEventos, inscrever } from '@/lib/api';
import EventoCard from '@/components/EventoCard';

export default function Home() {
  const [eventos, setEventos] = useState([]);
  const [mensagem, setMensagem] = useState(null);

  async function carregarEventos() {
    try {
      setEventos(await getEventos());
    } catch (erro) {
      setMensagem({ tipo: 'erro', texto: erro.message });
    }
  }

  useEffect(() => { carregarEventos(); }, []);

  async function handleInscrever(eventoId, participanteId) {
    const { ok, dados } = await inscrever(eventoId, participanteId);
    if (!ok) {
      setMensagem({ tipo: 'erro', texto: dados.erro }); // ex.: "Evento lotado"
      return;
    }
    setMensagem({ tipo: 'sucesso', texto: 'Inscrição realizada!' });
    carregarEventos(); // atualiza as vagas na tela
  }

  return (
    <main>
      <h1>EventoSENAI</h1>
      {mensagem && <p className={mensagem.tipo}>{mensagem.texto}</p>}

      <section className="grid">
        {eventos.map(ev => <EventoCard key={ev.id} evento={ev} />)}
      </section>

      {/* TODO: <FormParticipante /> e <FormInscricao onInscrever={handleInscrever} /> */}
    </main>
  );
}
```

> Por que a página tem `'use client'`? Ela usa `useState` e `useEffect`, que só funcionam em componentes que rodam no navegador. Componentes sem estado, como o `EventoCard`, não precisam da diretiva.

> Por que `app.use(cors())` na API? O Next roda em `localhost:3000` e a API em `localhost:3333`: são origens diferentes, e sem CORS liberado o navegador bloqueia a resposta. Teste: comente a linha, recarregue a página e veja o erro no console (F12).

**Teste de ponta a ponta:** cadastre um participante pela página, inscreva-o em um evento e confira no Workbench com `SELECT * FROM inscricoes;` que a linha foi gravada.

## Entrega e avaliação

A nota vai de 0 a 100 e metade dela depende de o sistema funcionar de ponta a ponta na apresentação.

**Checklist de entrega**

- [ ] `script.sql` roda do zero sem erro e já traz dados de teste
- [ ] DER (imagem) na pasta `database/`
- [ ] Todas as rotas da tabela da etapa 2 funcionando
- [ ] Coleção do Thunder Client/Postman exportada
- [ ] Front lista eventos, cadastra participante e faz inscrição
- [ ] `.env` fora do repositório e `README.md` explicando como rodar as três partes

**Rubrica**

| Critério | Pontos | O que o professor confere |
| --- | --- | --- |
| Modelagem e script SQL | 20 | PK, FK, UNIQUE e CHECK corretos; DER coerente com o script |
| API e rotas REST | 25 | Verbos e códigos HTTP certos; consultas com `?` |
| Regras de negócio | 15 | Bloqueio de inscrição duplicada e de evento lotado |
| Front-end e integração | 25 | Dados vêm da API; mensagens de erro na tela; vagas atualizam |
| Organização e README | 5 | Estrutura de pastas, commits frequentes, instruções claras |
| Apresentação oral | 10 | A dupla explica o caminho de um dado do formulário até o banco |

**Desafios extras** (até +10 pontos, fora do limite de 100)

- Filtro de eventos por categoria na página (`GET /eventos?categoria=2`)
- Tela de administração para criar, editar e excluir eventos
- Bloquear inscrição em evento com data no passado

**Pergunta para a apresentação:** o professor vai apontar um trecho de um componente do front e pedir que a dupla mostre qual rota da API ele chama e qual consulta SQL roda no fim.
