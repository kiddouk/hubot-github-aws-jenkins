# Description:
#   Buffer each message from Github to redis
#   Periodically try to push each buffered message to Jenkins.
#   If jenkins is not available, we will try to raise the capacity on the
#   auto sclaing group in order to get one.
#
# Dependencies:
#   "node-schedule" : "~0.5.1",
#
# Configuration:
#   HUBOT_SCHEDULE_DEBUG - set "1" for debug
#
# Commands:
#   nothing
#
# Author:
#   sebastien requiem <sebastien.requiem@gmail.com>

# configuration settings
config =
  debug: process.env.HUBOT_SCHEDULE_DEBUG
  dont_receive: process.env.HUBOT_SCHEDULE_DONT_RECEIVE
  aws_key: process.env.AWS_ACCESS_KEY_ID
  redis_url: process.env.REDIS_URL
  jenkins_url: process.env.JENKINS_URL
  jenkins_ping: process.env.JENKINS_PING
  aws_asg_name: process.env.AWS_ASG_NAME
  aws_region: process.env.AWS_REGION
  announce_channel: process.env.HUBOT_BROADCAST_CHANNEL
  redis_key: "github.push"

schedule = require('node-schedule')
Promise = require('bluebird')
Redis = require('redis')
rp = require('request-promise')
AWS = require('aws-sdk')
{TextMessage} = require('hubot')

module.exports = (robot) ->
  client = Redis.createClient(config.redis_url)
  Promise.promisifyAll client

  robot.brain.on 'loaded', =>
        rule = new schedule.RecurrenceRule()
        rule.minute = new schedule.Range(0, 59, 1)
        schedule.scheduleJob rule, () ->
          client.lrangeAsync config.redis_key, 0, -1
            .then (pushes) ->
              return [] unless pushes.length
              console.log config.jenkins_ping
              rp config.jenkins_ping
                .then () ->
                  client.delAsync config.redis_key
                    .then () ->
                      return pushes
                .catch (err) ->
                  autoscaling = new AWS.AutoScaling({region: config.aws_regions})

                  params =
                    AutoScalingGroupNames: [config.aws_asg_name]
                    MaxRecords: 1
                    
                  autoscaling.describeAutoScalingGroups params, (err, data) ->
                    if err?
                      console.log err
                      return announce_error(robot)
                    console.log data
                    if data.AutoScalingGroups[0].DesiredCapacity == 1
                      console.log "Just waiting for Jenkins to come up online"
                      return
                      
                    params =
                      AutoScalingGroupName: config.aws_asg_name,
                      DesiredCapacity: 1,
                      HonorCooldown: false

                    autoscaling.setDesiredCapacity params, (err, data) ->
                      if err?
                        console.log err
                        return announce_error(robot)
                      destination =
                        room: config.announce_channel

                      robot.send destination, "I received a Github push but our Jenkins seems to be down. Starting a new one..."
                  return []
          .map (push) ->
            options =
              method: 'POST',
              uri: config.jenkins_url,
              headers: {'x-github-event': 'push'}
              body: JSON.parse push
              json: true
            rp(options)
              .then (answer) ->
                console.log "payload sent to Jenkins"
              .catch (err) ->
                console.log "NOK"
                console.log err
                client.lpush config.redis_key, push

  robot.router.post '/github', (req, res) ->
    payload = req.body
    client.lpushAsync 'github.push', JSON.stringify(payload)
      .then () ->
        res.json("OK")

  robot.respond /ping jenkins/i, (res) ->
    rp config.jenkins_ping
      .then () ->
        res.reply "Jenkins is live at : " + config.jenkins_ping
      .catch (err) ->
        res.reply "Jenkins is dead. Just commit some code to wake him up"
  
  
announce_error = (robot) ->
  destination =
    room: config.announce_channel

  robot.send destination, "Cannot change desired capacity on ASG : " + config.aws_asg_name + ". So don't expect jenkins to be up and running. Also, I wrote some logs so you can investigate."
