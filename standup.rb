require 'sinatra'
require 'erb'
require 'redis'
require 'json'
require 'date'
require 'securerandom'

#ENV["PORT"] = "8080"

redis = Redis.new(url: ENV["REDIS_URL"])
#redis=Redis.new(:host => '127.0.0.1', :port => 6379)

set :bind, '0.0.0.0'
set :port, ENV["PORT"]

def retrieve_standup(redis, uuid, date)
  if redis.exists("#{uuid}:standups")
    if redis.hexists("#{uuid}:standups", date)
      tasksjson = redis.hget("#{uuid}:standups", date)
    end
  end
  if tasksjson.nil?
    {}
  else
    JSON.parse(tasksjson)
  end
end

def list_standups(redis, uuid)
  if redis.exists("#{uuid}:standups")
    if redis.hlen("#{uuid}:standups") > 0
      redis.hkeys("#{uuid}:standups").map{|standup|Date.parse(standup)}.sort{|a,b| b<=>a }
    end
  end
end

get '/' do
  @name = params["name"]
  @uuid = params["uuid"]
  if @uuid.nil?
    if @name.nil?
    else
      @uuid = nil
      @standupdates = []
      @standuptasks = []
    end
  else
    @name = redis.get("#{@uuid}:name")
    @standupdates = list_standups(redis, @uuid)
    if params["date"].nil?
      @standuptasks = retrieve_standup(redis, @uuid, @standupdates.first.strftime)
    else
      @date = params["date"]
      @standuptasks = retrieve_standup(redis, @uuid, @date)
    end
  end

=begin
  @name = params["name"]

  unless params["uuid"].nil?
    # Existing user
    @uuid = params["uuid"]
    @standupdates = list_standups(redis, @uuid)
    if params["date"].nil?
      unless @standupdates.nil?
        @date=Date.today.strftime
        @standuptasks = retrieve_standup(redis, @uuid, @standupdates.last.strftime)
      else
        @date=Date.today.strftime
        @standupdates = []
        @standuptasks = []
      end
    else
      @date=params["date"]
      @standuptasks = retrieve_standup(redis, @uuid, @date)
    end
  else
    # New User
    @date=Date.today.strftime
    @uuid = nil
    @standupdates = []
    @standuptasks = []
  end
=end
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

  if params["uuid"].nil?
    @uuid = SecureRandom.uuid
  else
    @uuid = params["uuid"]
  end

  redis.set("#{@uuid}:name", params["name"])

  if params["date"].nil?
    redis.hset("#{@uuid}:standups", Date.today.strftime, JSON.dump(record))
    redirect "./?uuid=#{@uuid}"
  else
    @date=params["date"]
    redis.hset("#{@uuid}:standups", @date, JSON.dump(record))
    redirect "./?uuid=#{@uuid}&date=#{@date}"
  end

  #redis.hset(@name, @date, JSON.dump(record))

  #@standupdates = list_standups(redis, @name)
  #if @standupdates.nil?
  #  @standupdates = []
  #end

  #@standuptasks = retrieve_standup(redis, @name, @date)
  #erb :index
end
