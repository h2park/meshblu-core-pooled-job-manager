JobManager = require 'meshblu-core-job-manager'
debug = require('debug')('meshblu-core-pooled-job-manager:pooled-job-manager')
Benchmark = require 'simple-benchmark'
colors = require 'colors'

class PooledJobManager
  constructor: ({@pool,@timeoutSeconds,@jobLogger,@jobLogSampleRate}) ->
    throw new Error('PooledJobManager needs a pool') unless @pool?
    throw new Error('PooledJobManager needs timeoutSeconds') unless @timeoutSeconds?
    throw new Error('PooledJobManager needs a jobLogger') unless @jobLogger?
    throw new Error('PooledJobManager needs a jobLogSampleRate') unless @jobLogSampleRate?

  poolStats: =>
    name: @pool.getName()
    poolSize: @pool.getPoolSize()
    availableObjects: @pool.availableObjectsCount()
    waitingClients: @pool.waitingClientsCount()
    max: @pool.getMaxPoolSize()
    min: @pool.getMinPoolSize()

  do: (requestQueue, responseQueue, request, callback) =>
    debug '->do'
    benchmark = new Benchmark label: 'pooled-job-manager'
    debug 'Stats:', JSON.stringify @poolStats()
    @pool.acquire (error, client) =>
      debug '@pool.acquire', benchmark.toString()
      delete error.code if error?
      return callback error if error?

      client.jobManager ?= new JobManager {client, @timeoutSeconds, @jobLogSampleRate}
      client.jobManager.do requestQueue, responseQueue, request, (error, response) =>
        @pool.release client
        debug '@pool.release', benchmark.toString()

        @jobLogger.log {error,request,response}, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error, response

  createResponse: (responseQueue, request, callback) =>
    debug '->createResponse'
    benchmark = new Benchmark label: 'pooled-job-manager'
    debug 'Stats:', JSON.stringify @poolStats()
    @pool.acquire (error, client) =>
      debug '@pool.acquire', benchmark.toString()
      delete error.code if error?
      return callback error if error?
      jobManager = new JobManager {client, @timeoutSeconds, @jobLogSampleRate}
      jobManager.createResponse responseQueue, request, (error) =>
        @pool.release client
        debug '@pool.release', benchmark.toString()
        @jobLogger.log {error,request,response:{}}, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error

  getResponse: (responseQueue, requestId, callback) =>
    debug '->getResponse'
    benchmark = new Benchmark label: 'pooled-job-manager'
    debug 'Stats:', JSON.stringify @poolStats()
    @pool.acquire (error, client) =>
      debug '@pool.acquire', benchmark.toString()
      delete error.code if error?
      return callback error if error?
      jobManager = new JobManager {client, @timeoutSeconds, @jobLogSampleRate}
      jobManager.getResponse responseQueue, requestId, (error, result) =>
        @pool.release client
        debug '@pool.release', benchmark.toString()
        @jobLogger.log {error,request: { requestId }, response:{}}, (jobLoggerError) =>
          return callback jobLoggerError if jobLoggerError?
          callback error, result

module.exports = PooledJobManager
