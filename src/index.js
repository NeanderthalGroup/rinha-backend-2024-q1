const fastify = require("fastify")({ logger: false });
const { Pool } = require("pg");

const client = new Pool({
  user: "postgres",
  host: "localhost",
  database: "rinha-backend",
  password: "Thiago@123",
  port: 5432,
});

class AppError extends Error {
  constructor(message, statusCode = 400) {
    super(message);
    this.name = this.constructor.name;
    this.statusCode = statusCode;
    Error.captureStackTrace(this, this.constructor);
  }
}

async function handleClientTransactions(idCliente, valor, tipo, descricao) {
  if (!Number.isInteger(Number(idCliente)) || idCliente <= 0) {
    throw new AppError(
      "O id do cliente é inválido. Verifique e tente novamente",
      404
    );
  }
  if (tipo !== "c" && tipo !== "d") {
    throw new AppError(
      'Tipo de transação inválido. Use "c" para crédito ou "d" para débito.'
    );
  }
  if (descricao.length < 1 || descricao.length > 10) {
    throw new AppError("A descrição deve ter entre 1 e 10 caracteres.");
  }
  if (!Number.isInteger(valor) || valor < 0) {
    throw new AppError("O valor deve ser um número inteiro positivo.");
  }

  const clientData = await client.query("SELECT * FROM cliente WHERE id = $1", [
    idCliente,
  ]);

  if (clientData.rows.length === 0) {
    throw new AppError("Cliente não encontrado.", 422);
  }

  const balanceData = await client.query(
    "SELECT * FROM saldo WHERE cliente_id = $1",
    [idCliente]
  );

  const currentBalance = clientData.rows[0].limite - -balanceData.rows[0].valor;

  if (tipo === "d" && valor >= currentBalance) {
    throw new AppError("Não há limite para completar a transação", 422);
  }

  const updatedBalance =
    tipo === "d"
      ? balanceData.rows[0].valor - valor
      : balanceData.rows[0].valor + valor;

  await client.query("SELECT handle_account_transaction($1, $2, $3, $4)", [
    idCliente,
    valor,
    tipo,
    descricao,
  ]);

  return {
    limite: clientData.rows[0].limite,
    saldo: updatedBalance,
  };
}

async function handleAccountStatements(idCliente) {
  if (!Number.isInteger(Number(idCliente)) || idCliente <= 0) {
    throw new AppError(
      "O id do cliente é inválido. Verifique e tente novamente",
      404
    );
  }

  return {
    saldo: {
      total: 0,
      data_extrato: new Date().toISOString(),
      limite: 0,
    },
    ultimas_transacoes: [
      {
        valor: 10,
        tipo: "c",
        descricao: "descricao",
        realizada_em: "2024-01-17T02:34:38.543030Z",
      },
      {
        valor: 90000,
        tipo: "d",
        descricao: "descricao",
        realizada_em: "2024-01-17T02:34:38.543030Z",
      },
    ],
  };
}

fastify.post(
  "/clientes/:idCliente/transacoes",
  async function handler(request, reply) {
    try {
      const transacao = await handleClientTransactions(
        request.params.idCliente,
        request.body.valor,
        request.body.tipo,
        request.body.descricao
      );
      return reply.code(200).send(transacao);
    } catch (error) {
      if (error instanceof AppError) {
        return reply.code(error.statusCode).send({ error: error.message });
      } else {
        console.error(error);
        return reply.code(500).send({ error: "Internal error" });
      }
    }
  }
);

fastify.get(
  "/clientes/:idCliente/extrato",
  async function handler(request, reply) {
    try {
      const transacao = await handleAccountStatements(request.params.idCliente);
      return reply.code(200).send(transacao);
    } catch (error) {
      if (error instanceof AppError) {
        return reply.code(error.statusCode).send({ error: error.message });
      } else {
        return reply.code(500).send({ error: "Internal error" });
      }
    }
  }
);

fastify.listen({ port: 3000 }, (err) => {
  console.log("Server running");
  if (err) {
    fastify.log.error(err);
    process.exit(1);
  }
});
