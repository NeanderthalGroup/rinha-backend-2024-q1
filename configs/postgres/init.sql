CREATE TABLE cliente (
    id INT PRIMARY KEY,
    limite INT NOT NULL,
    saldo_inicial INT NOT NULL
);

CREATE TABLE transacao (
	id SERIAL PRIMARY KEY,
	cliente_id INTEGER NOT NULL,
	valor INTEGER NOT NULL,
	tipo CHAR(1) NOT NULL,
	descricao VARCHAR(200) NOT NULL,
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

INSERT INTO cliente (Id, limite, saldo_inicial) VALUES
(1, 100000, 0),
(2, 80000, 0),
(3, 1000000, 0),
(4, 10000000, 0),
(5, 500000, 0);

CREATE OR REPLACE FUNCTION gerencia_transacao(
    p_cliente_id INTEGER,
    p_valor INTEGER,
    p_tipo CHAR(1),
    p_descricao VARCHAR(10)
)
RETURNS JSON AS $$
DECLARE
    transaction_info JSON;
    v_saldo_atual INTEGER;
    v_saldo_inicial INTEGER;
BEGIN
    INSERT INTO transacao (cliente_id, valor, tipo, descricao)
    VALUES (p_cliente_id, p_valor, p_tipo, p_descricao);

    SELECT valor INTO v_saldo_atual FROM saldo WHERE cliente_id = p_cliente_id;

    IF p_tipo = 'D' THEN
        v_saldo_atual := v_saldo_atual - p_valor;
    END IF;

    IF p_tipo = 'C' THEN
        v_saldo_atual := v_saldo_atual + p_valor;
    END IF;

    IF NOT FOUND THEN
        SELECT saldo_inicial INTO v_saldo_inicial FROM cliente WHERE id = p_cliente_id;

        IF p_tipo = 'D' THEN
            v_saldo_atual := v_saldo_inicial - p_valor;
            INSERT INTO saldo (cliente_id, valor) VALUES (p_cliente_id, v_saldo_atual);
        END IF;

        IF p_tipo = 'C' THEN
            v_saldo_atual := v_saldo_inicial + p_valor;
            INSERT INTO saldo (cliente_id, valor) VALUES (p_cliente_id, v_saldo_atual);
        END IF;
    ELSE
        UPDATE saldo SET valor = v_saldo_atual WHERE cliente_id = p_cliente_id;
    END IF;

    transaction_info := json_build_object(
        'client_id', p_cliente_id,
        'current_balance', v_saldo_atual,
        'type', p_tipo
    );

    RETURN transaction_info;
END;
$$ LANGUAGE plpgsql;