JobManager = require 'meshblu-core-job-manager'
debug = require('debug')('meshblu-server-http:pooled-job-manager')
Benchmark = require 'simple-benchmark'
colors = require 'colors'

class PooledJobManager
  constructor: ({@pool,@timeoutSeconds,@jobLogger}) ->
    throw new Error('PooledJobManager needs a pool') unless @pool?
    throw new Error('PooledJobManager needs timeoutSeconds') unless @timeoutSeconds?
    throw new Error('PooledJobManager needs a jobLogger') unless @jobLogger?

  poolStats: =>
    name: @pool.getName()
    poolSize: @pool.getPoolSize()
    availableObjects: @pool.availableObjectsCount()
    waitingClients: @pool.waitingClientsCount()
    max: @pool.getMaxPoolSize()
    min: @pool.getMinPoolSize()

  do: (requestQueue, responseQueue, request, callback) =>
    benchmark = new Benchmark label: 'pooled-job-manager'
    debug 'Stats:', JSON.stringify @poolStats()
    @pool.acquire (error, client) =>
      debug '@pool.acquire', benchmark.toString()
      return callback error if error?

      jobManager = new JobManager {client, @timeoutSeconds}
      jobManager.do requestQueue, responseQueue, request, (error, response) =>
        @pool.release client
        debug '@pool.release', benchmark.toString()

        @jobLogger.log {error,request,response,elapsedTime:benchmark.elapsed()}, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error, response

module.exports = PooledJobManager
