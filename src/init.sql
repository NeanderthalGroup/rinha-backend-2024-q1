-- Parte 1: Criar tabelas

CREATE TABLE cliente (
    id SERIAL PRIMARY KEY,
    limite INTEGER NOT NULL
);

CREATE TABLE transacao (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    valor INTEGER NOT NULL,
    tipo CHAR(1) NOT NULL,
    descricao VARCHAR(10) NOT NULL,
    data_criacao TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_cliente_transacao_id
        FOREIGN KEY (cliente_id) REFERENCES cliente(id)
);

CREATE TABLE saldo (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    valor INTEGER NOT NULL,
    CONSTRAINT fk_cliente_saldo_id
        FOREIGN KEY (cliente_id) REFERENCES cliente(id)
);

-- Inserir dados iniciais
INSERT INTO cliente (limite)
VALUES
    (100000),
    (80000),
    (1000000),
    (10000000),
    (500000);

INSERT INTO saldo (cliente_id, valor)
    SELECT id, 0 FROM cliente;

-- Parte 2: Definir a função

CREATE OR REPLACE FUNCTION handle_account_transaction(
    IN p_cliente_id INTEGER,
    IN p_valor INTEGER,
    IN p_tipo CHAR(1),
    IN p_descricao VARCHAR(10)
)
RETURNS VOID AS $$
DECLARE
    v_saldo_atual INTEGER;
BEGIN
    INSERT INTO transacao (cliente_id, valor, tipo, descricao)
    VALUES (p_cliente_id, p_valor, p_tipo, p_descricao);

    SELECT valor INTO v_saldo_atual FROM saldo WHERE cliente_id = p_cliente_id;
    
    IF p_tipo = 'd' THEN
        v_saldo_atual := v_saldo_atual - p_valor;
    ELSIF p_tipo = 'c' THEN
        v_saldo_atual := v_saldo_atual + p_valor;
    END IF;

    UPDATE saldo SET valor = v_saldo_atual WHERE cliente_id = p_cliente_id;
END;
$$ LANGUAGE plpgsql;
