require 'sinatra'
require 'erb'
require 'redis'
require 'json'

#ENV["PORT"] = "8080"

redis = Redis.new(url: ENV["REDIS_URL"])
#redis=Redis.new(:host => '127.0.0.1', :port => 6379)

set :bind, '0.0.0.0'
set :port, ENV["PORT"]

def retrieve_standup(redis)
  tasksjson = redis.get("standup")
  if tasksjson.nil?
    ""
  else
    JSON.parse(tasksjson)
  end
end

get '/' do
  @standuptasks = retrieve_standup(redis)
  erb :index
end

post '/' do
  tasks = params["tasks"][0]
  record = {
    "complete" => {"title" => "Complete", "header" => ":lemming_win: *Complete* :lemming_win:", "tasks" => []},
    "inprogress" => {"title" => "In Progress", "header" => ":lemming: *Tasks in Progress* :lemming:", "tasks" => []},
    "validation" => {"title" => "Validation", "header" => ":mantelpiece_clock: *Validation* :mantelpiece_clock:", "tasks" => []},
    "upnext" => {"title" => "Lemming Lookout", "header" => ":lemming_lookout: *Up Next* :lemming_lookout:", "tasks" => []},
    "blocked" => {"title" => "Blocked", "header" => ":blocker: *Blocked* :blocker:", "tasks" => []}
  }

  i = 0
  while i < tasks["summary"].length do
    task = {"summary" => tasks["summary"][i], "description" => tasks["description"][i]}
    case tasks["status"][i]
    when "complete"
      record["complete"]["tasks"].push(task)
    when "inprogress"
      record["inprogress"]["tasks"].push(task)
    when "validation"
      record["validation"]["tasks"].push(task)
    when "upnext"
      record["upnext"]["tasks"].push(task)
    when "blocked"
      record["blocked"]["tasks"].push(task)
    end
    i += 1
  end
  redis.set("standup", JSON.dump(record))

  @standuptasks = retrieve_standup(redis)
  erb :index
end
