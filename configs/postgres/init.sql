CREATE TABLE cliente (
    id INT PRIMARY KEY,
    limite INT NOT NULL,
    saldo_inicial INT NOT NULL
);

CREATE TABLE saldo (
    id SERIAL PRIMARY KEY,
    cliente_id INTEGER NOT NULL,
    valor INTEGER NOT NULL,
    CONSTRAINT fk_cliente_saldo_id FOREIGN KEY (cliente_id) REFERENCES cliente(id),
    CONSTRAINT unique_cliente_id UNIQUE (cliente_id)
);

CREATE TABLE transacao (
	id SERIAL PRIMARY KEY,
	cliente_id INTEGER NOT NULL,
	valor INTEGER NOT NULL,
	tipo CHAR(1) NOT NULL,
	descricao VARCHAR(10) NOT NULL,
    data_criacao TIMESTAMP NOT NULL DEFAULT TO_TIMESTAMP(TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.US'), 'YYYY-MM-DD"T"HH24:MI:SS.US'),
	CONSTRAINT fk_cliente_transacao_id
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
    v_saldo_inicial INTEGER;
    v_cliente_limite INTEGER;
    v_saldo_atual INTEGER;
BEGIN
    BEGIN
        SELECT limite, saldo_inicial, valor 
            INTO v_cliente_limite, v_saldo_inicial, v_saldo_atual
        FROM cliente c
            LEFT JOIN saldo s ON c.id = s.cliente_id
        WHERE c.id = p_cliente_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Cliente não encontrado.';
        END IF;

        IF p_tipo = 'd' THEN
            v_saldo_atual := COALESCE(v_saldo_atual, v_saldo_inicial) - p_valor;

            IF v_saldo_atual < -v_cliente_limite THEN
                RAISE EXCEPTION 'Não há limite para completar a transação';
            END IF;
        ELSIF p_tipo = 'c' THEN
            v_saldo_atual := COALESCE(v_saldo_atual, v_saldo_inicial) + p_valor;
        END IF;

        INSERT INTO saldo (cliente_id, valor)
        VALUES (p_cliente_id, v_saldo_atual)
        ON CONFLICT (cliente_id) DO UPDATE SET valor = v_saldo_atual;

        INSERT INTO transacao (cliente_id, valor, tipo, descricao)
        VALUES (p_cliente_id, p_valor, p_tipo, p_descricao);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object('error', SQLERRM);
    END;

    -- Return transaction information
    RETURN json_build_object(
        'limite', v_cliente_limite,
        'saldo', v_saldo_atual
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION consulta_extrato(
    p_cliente_id INTEGER
)
RETURNS JSON AS $$
DECLARE
    extrato_cliente JSON;
    iso8601_date VARCHAR;
    v_cliente_limite INTEGER;
    v_saldo_inicial INTEGER;
    v_saldo_atual INTEGER;
BEGIN
    BEGIN
        SELECT limite, saldo_inicial, valor 
            INTO v_cliente_limite, v_saldo_inicial, v_saldo_atual
        FROM cliente c
            LEFT JOIN saldo s ON c.id = s.cliente_id
        WHERE c.id = p_cliente_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Cliente não encontrado.';
        END IF;

        IF v_saldo_atual IS NULL THEN
            v_saldo_atual := v_saldo_inicial;
        END IF;

        SELECT json_agg(row_to_json(t))
        INTO extrato_cliente
        FROM (
            SELECT valor, tipo, descricao, data_criacao as realizada_em
            FROM transacao
            WHERE cliente_id = p_cliente_id
            ORDER BY data_criacao DESC
            LIMIT 10
        ) t;

        IF extrato_cliente IS NULL THEN
            extrato_cliente := json_build_array();
        END IF;

        SELECT to_char(current_timestamp, 'YYYY-MM-DD"T"HH24:MI:SS.US') INTO iso8601_date;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object('error', SQLERRM);
    END;

    -- Return transaction information
    RETURN json_build_object(
        'saldo', json_build_object(
            'total', v_saldo_atual,
            'data_extrato', iso8601_date,
            'limite', v_cliente_limite
        ),
        'ultimas_transacoes', extrato_cliente
    );
END;
$$ LANGUAGE plpgsql;