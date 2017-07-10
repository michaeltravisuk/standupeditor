require 'sinatra'
require 'erb'
require 'redis'
require 'json'
require 'date'

#ENV["PORT"] = "8080"

redis = Redis.new(url: ENV["REDIS_URL"])
#redis=Redis.new(:host => '127.0.0.1', :port => 6379)

set :bind, '0.0.0.0'
set :port, ENV["PORT"]

def retrieve_standup(redis, name, date)
  if redis.exists(name)
    if redis.hexists(name, date)
      tasksjson = redis.hget(name, date)
    end
  end
  if tasksjson.nil?
    {}
  else
    JSON.parse(tasksjson)
  end
end

def list_standups(redis, name)
  if redis.exists(@name)
    if redis.hlen(@name) > 0
      redis.hkeys(@name).map{|standup|Date.parse(standup)}.sort
    end
  end
end

get '/' do
  unless params["name"].nil?
    @name = params["name"]
    @standupdates = list_standups(redis, @name)
    if params["date"].nil?
      unless @standupdates.nil?
        @date=Date.today.strftime
        @standuptasks = retrieve_standup(redis, @name, @standupdates.last.strftime)
      else
        @date=Date.today.strftime
        @standupdates = []
        @standuptasks = []
      end
    else
      @date=params["date"]
      @standuptasks = retrieve_standup(redis, @name, @date)
    end
  else
    @name = nil
    @standupdates = []
  end
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

  @name=params["name"]

  if params["date"].nil?
    @date=Date.today.strftime
  else
    @date=params["date"]
  end

  redis.hset(@name, @date, JSON.dump(record))

  @standupdates = list_standups(redis, @name)
  if @standupdates.nil?
    @standupdates = []
  end

  @standuptasks = retrieve_standup(redis, @name, @date)
  erb :index
end
