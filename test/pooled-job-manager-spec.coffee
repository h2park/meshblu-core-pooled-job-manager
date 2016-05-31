_ = require 'lodash'
redis = require 'fakeredis'
UUID = require 'uuid'
{Pool} = require 'generic-pool'
PooledJobManager = require '../'
JobManager = require 'meshblu-core-job-manager'

describe 'PooledJobManager', ->
  beforeEach ->
    @redisKey = UUID.v1()

    pool = new Pool
      max: 1
      min: 0
      create: (callback) =>
        client = redis.createClient @redisKey
        client = _.bindAll client, _.functionsIn(client)
        callback null, client
      destroy: (client) => client.end true

    @fakeJobLogger = log: sinon.stub().yields null

    @sut = new PooledJobManager {pool, timeoutSeconds: 1, jobLogger: @fakeJobLogger, jobLogSampleRate: 1}

  beforeEach ->
    client = redis.createClient @redisKey
    client = _.bindAll client, _.functionsIn(client)
    @jobManager = new JobManager {client, timeoutSeconds: 1, jobLogSampleRate: 0}

  describe '->do', ->
    beforeEach (done) ->
      @jobManager.getRequest ['request'], (error, job) =>
        throw error if error?
        throw new Error('Timeout waiting for job') unless job?
        response =
          metadata:
            responseId: job.metadata.responseId

        @jobManager.createResponse 'response', response, (error) =>
          throw error if error?

      request =
        metadata:
          jobType: 'SendMessage'
        rawData: JSON.stringify devices:['receiver-uuid'], payload: 'boo'

      @sut.do 'request', 'response', request, (error, @response) => done error

    it 'should yield a response', ->
      expect(@response).to.exist

    it 'should call jobLogger.log', ->
      expect(@fakeJobLogger.log).to.have.been.called

  describe '->createResponse', ->
    beforeEach (done) ->
      request =
        metadata:
          responseId: 'response-id'
          jobType: 'SendMessage'
        rawData: JSON.stringify devices:['receiver-uuid'], payload: 'boo'

      @sut.createResponse 'response', request, (error) => done error

    it 'should call jobLogger.log', ->
      expect(@fakeJobLogger.log).to.have.been.called
