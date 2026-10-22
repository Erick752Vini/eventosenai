require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/eventos',      require('./routes/eventos'));
app.use('/participantes', require('./routes/participantes'));
app.use('/inscricoes',   require('./routes/inscricoes'));

app.listen(process.env.PORT, () =>
  console.log(`API rodando em http://localhost:${process.env.PORT}`)
);
