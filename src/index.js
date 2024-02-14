const fastify = require('fastify')({ logger: false })

async function handleClientTransactions({valor, tipo, descricao}) {
  if (tipo !== 'c' && tipo !== 'd') {
    throw new Error('Tipo de transação inválido. Use "c" para crédito ou "d" para débito.')
  }
  if (descricao.length < 1 || descricao.length > 10) {
    throw new Error('A descrição deve ter entre 1 e 10 caracteres.')
  }
  if (!Number.isInteger(valor) || valor < 0) {
    throw new Error('O valor deve ser um número inteiro positivo.')
  }

  return {
    data: {}
  }
}

fastify.post('/clientes/:idCliente/transacoes', async function handler (request, reply) {
  const idCliente = request.params.idCliente;

  if (!Number.isInteger(Number(idCliente)) || idCliente <= 0) {
    reply.status(400).send({ error: 'idCliente inválido. Deve ser um número inteiro positivo.' });
    return;
  }

  const { valor, tipo, descricao } = request.body;
  try {
    const transacao = await handleClientTransactions({ valor, tipo, descricao })
    reply.code(201).send(transacao)
  } catch (error) {
      reply.code(400).send({ error: error.message })
  } finally {
    reply.code(500).send({ error: 'Internal error' })
  }
})

fastify.listen({ port: 3000 }, (err) => {
  console.log('Server running')
  if (err) {
    fastify.log.error(err)
    process.exit(1)
  }
})