const fastify = require("fastify")({ logger: false });
const { Pool } = require("pg");

const client = new Pool({
  host: process.env.DB_HOSTNAME ?? "db",
  user: process.env.DB_USERNAME ?? "admin",
  password: process.env.DB_PASSWORD ?? "123",
  database: process.env.DB_DATABASE ?? "rinha",
  port: process.env.DB_PORT ?? 5432,
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
      "Tipo de transação inválido. Use 'c' para crédito ou 'd' para débito."
    );
  }

  if (descricao.length < 1 || descricao.length > 10) {
    throw new AppError("A descrição deve ter entre 1 e 10 caracteres.");
  }

  if (!Number.isInteger(valor) || valor < 0) {
    throw new AppError("O valor deve ser um número inteiro positivo.");
  }

  let procReturn = await client.query(`SELECT gerencia_transacao(${idCliente}, ${valor}, '${tipo}', '${descricao}') AS result;`)

  if (procReturn?.rows[0]?.result?.error == 'Cliente não encontrado.') {
    throw new AppError(procReturn?.rows[0]?.result?.error, 404);
  }

  if (procReturn?.rows[0]?.result?.error) {
    throw new AppError(procReturn?.rows[0]?.result?.error, 422);
  }
  
  return procReturn?.rows[0]?.result
}

async function handleAccountStatements(idCliente) {
  if (!Number.isInteger(Number(idCliente)) || idCliente <= 0) {
    throw new AppError(
      "O id do cliente é inválido. Verifique e tente novamente",
      404
    );
  }

  let procReturn = await client.query(`SELECT consulta_extrato(${idCliente}) AS result;`)

  if (procReturn?.rows[0]?.result?.error == 'Cliente não encontrado.') {
    throw new AppError(procReturn?.rows[0]?.result?.error, 404);
  }
  
  return procReturn?.rows[0]?.result;
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

fastify.get("/", (request, reply) => {
  return reply.code(200).send({ message: "Public Route Rinha 2024 Q1." });
});

fastify.listen({ host: '::', port: process.env.API_PORT ?? 3000 }, (err) => {
  console.log("Server running");
  if (err) {
    fastify.log.error(err);
    process.exit(1);
  }
});
