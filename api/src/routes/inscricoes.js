const router = require('express').Router();
const db = require('../db');

// ─────────────────────────────────────────────────────────────────────────────
// POST /inscricoes
// Inscreve um participante em um evento.
//
// Regras de negócio (obrigatórias pela atividade):
//   1. Verifica se o evento existe.
//   2. Verifica se ainda há vagas (vagas_restantes > 0). → 409 "Evento lotado"
//   3. Verifica se o participante já está inscrito. → 409 "Participante já inscrito"
// ─────────────────────────────────────────────────────────────────────────────
router.post('/', async (req, res) => {
  const { evento_id, participante_id } = req.body;

  if (!evento_id || !participante_id) {
    return res.status(400).json({ erro: 'Campos obrigatórios faltando: evento_id, participante_id' });
  }

  try {
    // 1. Busca o evento e calcula as vagas restantes
    const [eventos] = await db.query(`
      SELECT
        e.id,
        e.vagas,
        (e.vagas - COUNT(i.id)) AS vagas_restantes
      FROM eventos e
      LEFT JOIN inscricoes i ON i.evento_id = e.id
      WHERE e.id = ?
      GROUP BY e.id, e.vagas
    `, [evento_id]);

    if (eventos.length === 0) {
      return res.status(404).json({ erro: 'Evento não encontrado' });
    }

    // 2. Verifica vagas
    if (eventos[0].vagas_restantes <= 0) {
      return res.status(409).json({ erro: 'Evento lotado' });
    }

    // 3. Insere a inscrição (a UNIQUE constraint do banco impede duplicata)
    const [result] = await db.query(
      'INSERT INTO inscricoes (evento_id, participante_id) VALUES (?, ?)',
      [evento_id, participante_id]
    );

    res.status(201).json({ id: result.insertId });
  } catch (err) {
    // Código 1062 = inscrição duplicada (UNIQUE evento_id + participante_id)
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ erro: 'Participante já inscrito neste evento' });
    }
    console.error(err);
    res.status(500).json({ erro: 'Erro ao realizar inscrição' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /inscricoes/:id
// Cancela (remove) uma inscrição pelo ID.
// ─────────────────────────────────────────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    const [result] = await db.query(
      'DELETE FROM inscricoes WHERE id = ?',
      [req.params.id]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ erro: 'Inscrição não encontrada' });
    }
    res.status(204).send();
  } catch (err) {
    console.error(err);
    res.status(500).json({ erro: 'Erro ao cancelar inscrição' });
  }
});

module.exports = router;
