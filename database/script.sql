-- =====================================================================
-- PROJETO: EventoSENAI
-- DESCRIÇÃO: Plataforma de eventos escolares (palestras, oficinas e
--            workshops) em que alunos se inscrevem.
-- SGBD: MySQL 8.x
-- =====================================================================


-- =====================================================================
-- 1. CRIAÇÃO DO BANCO DE DADOS
-- =====================================================================
CREATE DATABASE IF NOT EXISTS eventosenai
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE eventosenai;


-- =====================================================================
-- 2. LIMPEZA (permite executar o script várias vezes sem erro)
--    A ordem é inversa à de criação, por causa das chaves estrangeiras.
-- =====================================================================
DROP TABLE IF EXISTS inscricoes;
DROP TABLE IF EXISTS eventos;
DROP TABLE IF EXISTS participantes;
DROP TABLE IF EXISTS categorias;


-- =====================================================================
-- 3. CRIAÇÃO DAS TABELAS
--    Ordem: categorias -> participantes -> eventos -> inscricoes
--    (tabelas "pai" primeiro, tabelas com FK depois)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 3.1 Tabela CATEGORIAS
--     Guarda os tipos de evento (Palestra, Oficina, Workshop).
-- ---------------------------------------------------------------------
CREATE TABLE categorias (
    id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome VARCHAR(50)  NOT NULL,

    CONSTRAINT pk_categorias      PRIMARY KEY (id),
    CONSTRAINT uq_categorias_nome UNIQUE (nome)      -- nome não pode repetir
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3.2 Tabela PARTICIPANTES
--     Guarda os alunos que podem se inscrever nos eventos.
-- ---------------------------------------------------------------------
CREATE TABLE participantes (
    id    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    nome  VARCHAR(100) NOT NULL,
    email VARCHAR(120) NOT NULL,
    turma VARCHAR(50)  NULL,

    CONSTRAINT pk_participantes       PRIMARY KEY (id),
    CONSTRAINT uq_participantes_email UNIQUE (email)  -- e-mail único
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3.3 Tabela EVENTOS
--     Cada evento pertence a UMA categoria (FK -> categorias).
-- ---------------------------------------------------------------------
CREATE TABLE eventos (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    titulo       VARCHAR(150) NOT NULL,
    descricao    TEXT         NULL,
    data_evento  DATETIME     NOT NULL,
    local        VARCHAR(100) NOT NULL,
    vagas        INT UNSIGNED NOT NULL,
    categoria_id INT UNSIGNED NOT NULL,

    CONSTRAINT pk_eventos           PRIMARY KEY (id),
    CONSTRAINT ck_eventos_vagas     CHECK (vagas > 0),  -- vagas > 0
    CONSTRAINT fk_eventos_categoria FOREIGN KEY (categoria_id)
        REFERENCES categorias (id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT   -- não permite apagar categoria que tenha eventos
) ENGINE = InnoDB;

-- ---------------------------------------------------------------------
-- 3.4 Tabela INSCRICOES
--     Tabela associativa (N:N) entre eventos e participantes.
--     A restrição UNIQUE (evento_id, participante_id) impede que o
--     mesmo participante se inscreva duas vezes no mesmo evento.
-- ---------------------------------------------------------------------
CREATE TABLE inscricoes (
    id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
    evento_id       INT UNSIGNED NOT NULL,
    participante_id INT UNSIGNED NOT NULL,
    data_inscricao  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP, -- automática

    CONSTRAINT pk_inscricoes              PRIMARY KEY (id),
    CONSTRAINT uq_inscricao_evento_part   UNIQUE (evento_id, participante_id),
    CONSTRAINT fk_inscricoes_evento       FOREIGN KEY (evento_id)
        REFERENCES eventos (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,   -- apagar evento remove suas inscrições
    CONSTRAINT fk_inscricoes_participante FOREIGN KEY (participante_id)
        REFERENCES participantes (id)
        ON UPDATE CASCADE
        ON DELETE CASCADE    -- apagar participante remove suas inscrições
) ENGINE = InnoDB;


-- =====================================================================
-- 4. INSERÇÃO DE DADOS DE TESTE
--    Ordem: categorias -> participantes -> eventos -> inscricoes
-- =====================================================================

-- 4.1 Categorias (ids 1, 2 e 3)
INSERT INTO categorias (nome) VALUES
    ('Palestra'),   -- id 1
    ('Oficina'),    -- id 2
    ('Workshop');   -- id 3

-- 4.2 Participantes (ids 1 a 6)
INSERT INTO participantes (nome, email, turma) VALUES
    ('Ana Beatriz Souza',  'ana.souza@aluno.senai.br',    'DS-2026-A'),  -- id 1
    ('Bruno Henrique Lima','bruno.lima@aluno.senai.br',   'DS-2026-A'),  -- id 2
    ('Camila Ferreira',    'camila.ferreira@aluno.senai.br','ELE-2026-B'),-- id 3
    ('Diego Martins',      'diego.martins@aluno.senai.br','MEC-2026-A'), -- id 4
    ('Eduarda Oliveira',   'eduarda.oliveira@aluno.senai.br','DS-2026-B'),-- id 5
    ('Felipe Andrade',     'felipe.andrade@aluno.senai.br','ELE-2026-B');-- id 6

-- 4.3 Eventos (ids 1 a 6) - categoria_id referencia a tabela categorias
INSERT INTO eventos (titulo, descricao, data_evento, local, vagas, categoria_id) VALUES
    ('Carreira em Tecnologia',
     'Palestra sobre mercado de trabalho e trajetórias profissionais na área de TI.',
     '2026-11-10 19:00:00', 'Auditório Principal', 100, 1),            -- Palestra

    ('Inteligência Artificial no Dia a Dia',
     'Palestra introdutória sobre IA generativa e seus impactos na indústria.',
     '2026-11-12 20:00:00', 'Auditório Principal', 3, 1),              -- Palestra

    ('Oficina de Arduino',
     'Montagem de circuitos e programação básica com Arduino.',
     '2026-11-17 14:00:00', 'Laboratório de Eletrônica', 20, 2),       -- Oficina

    ('Oficina de Soldagem Básica',
     'Prática de soldagem de componentes eletrônicos em placas.',
     '2026-11-19 09:00:00', 'Oficina Mecânica 2', 15, 2),              -- Oficina

    ('Workshop de Git e GitHub',
     'Versionamento de código, branches, pull requests e trabalho em equipe.',
     '2026-11-24 18:30:00', 'Laboratório de Informática 3', 25, 3),    -- Workshop

    ('Workshop de Modelagem de Banco de Dados',
     'Construção de DER e criação de tabelas relacionais em MySQL.',
     '2026-11-26 18:30:00', 'Laboratório de Informática 1', 30, 3);    -- Workshop

-- 4.4 Inscrições (data_inscricao é preenchida automaticamente)
INSERT INTO inscricoes (evento_id, participante_id) VALUES
    (1, 1), (1, 2), (1, 3), (1, 5),     -- Carreira em Tecnologia: 4 inscritos
    (2, 1), (2, 4), (2, 6),             -- IA no Dia a Dia: 3 inscritos (lotado)
    (3, 3), (3, 6),                     -- Oficina de Arduino: 2 inscritos
    (5, 1), (5, 2), (5, 5),             -- Workshop de Git: 3 inscritos
    (6, 2), (6, 5);                     -- Workshop de Modelagem: 2 inscritos
                                        -- (evento 4 fica sem inscritos de propósito,
                                        --  para testar o LEFT JOIN)


-- =====================================================================
-- 5. CONSULTAS DE TESTE
-- =====================================================================

-- ---------------------------------------------------------------------
-- 5.1 Listar todos os eventos com o nome da categoria (INNER JOIN)
-- ---------------------------------------------------------------------
SELECT
    e.id,
    e.titulo,
    c.nome AS categoria,
    e.data_evento,
    e.local,
    e.vagas
FROM eventos e
INNER JOIN categorias c ON c.id = e.categoria_id
ORDER BY e.data_evento;

-- ---------------------------------------------------------------------
-- 5.2 Listar os participantes inscritos em um evento específico
--     (exemplo: evento de id = 1; troque o número para testar outros)
-- ---------------------------------------------------------------------
SELECT
    e.titulo        AS evento,
    p.nome          AS participante,
    p.email,
    p.turma,
    i.data_inscricao
FROM inscricoes i
INNER JOIN eventos       e ON e.id = i.evento_id
INNER JOIN participantes p ON p.id = i.participante_id
WHERE e.id = 1
ORDER BY p.nome;

-- ---------------------------------------------------------------------
-- 5.3 Todos os eventos com total de inscritos e vagas restantes
--     LEFT JOIN garante que eventos SEM inscrições também apareçam.
-- ---------------------------------------------------------------------
SELECT
    e.id,
    e.titulo,
    c.nome                     AS categoria,
    e.vagas                    AS vagas_totais,
    COUNT(i.id)                AS total_inscritos,
    (e.vagas - COUNT(i.id))    AS vagas_restantes
FROM eventos e
INNER JOIN categorias c ON c.id = e.categoria_id
LEFT  JOIN inscricoes i ON i.evento_id = e.id
GROUP BY e.id, e.titulo, c.nome, e.vagas
ORDER BY e.id;

-- ---------------------------------------------------------------------
-- 5.4 Demonstração: o banco impede inscrição duplicada
--
--     A Ana (participante 1) já está inscrita no evento 1.
--     O comando abaixo, se executado normalmente, gera o erro:
--     "Error Code: 1062. Duplicate entry '1-1' for key
--      'inscricoes.uq_inscricao_evento_part'"
--
--     Está COMENTADO para não interromper a execução do script.
--     Para ver o erro, selecione a linha e execute (Ctrl+Enter):
-- ---------------------------------------------------------------------
-- INSERT INTO inscricoes (evento_id, participante_id) VALUES (1, 1);

-- Versão que NÃO interrompe o script: INSERT IGNORE transforma o erro em
-- aviso (warning) e a linha duplicada simplesmente não é inserida.
INSERT IGNORE INTO inscricoes (evento_id, participante_id) VALUES (1, 1);

-- Mostra o aviso gerado pela tentativa de duplicação
SHOW WARNINGS;

-- Prova de que continua existindo apenas 1 inscrição do participante 1
-- no evento 1 (o resultado deve ser 1):
SELECT COUNT(*) AS qtd_inscricoes_ana_no_evento_1
FROM inscricoes
WHERE evento_id = 1 AND participante_id = 1;

-- ---------------------------------------------------------------------
-- 5.5 Consultar os dados de cada tabela
-- ---------------------------------------------------------------------
SELECT * FROM categorias;
SELECT * FROM eventos;
SELECT * FROM participantes;
SELECT * FROM inscricoes;