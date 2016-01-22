# hubot-github-aws-jenkins
This plugin is a very specific one. So stpecific that I hardly doubt that you can use it "as is". So you can just walk away if you want.

Considering an AWS Cloudforamtion Stack that spawns a jenkins instance. And considering that this instance may shut itself down after few hours of inactivity. Assuming that you want to send all github push events to this jenkins machine to start your CI tests.

Under normal operations, this plugin will simply forward periodically all github push event payloads to the jenkins endpoint. If the jenkins instance appears to be dowm it will buffer all the github push events, and try to modify the auto scaling group in order to start a new jenkins instance. when that instance is available is pushes all the buffered payload.


# How does it work ?

This plugin goes hand in hand with [Jenkins Docker Repo](https://github.com/kiddouk/jenkins-docker) which contains a cloudformation template for your jenkins. When the stack is created, you will have an auto scaling group that contain one instance of Jenkins. This plugin will simply query the ASG to check on the health and forward (or buffer) the github requests.


