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

schedule = require('node-schedule')
{TextMessage} = require('hubot')

module.exports = (robot) ->
  robot.brain.on 'loaded', =>
    syncSchedules robot

  rule = new schedule.RecurrenceRule();
  rule.minute = new schedule.Range(0, 59, 1);
  schedule.scheduleJob rule, () ->
    console.log('yay');
