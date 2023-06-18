class Kredis::Types::OrderedSet < Kredis::Types::Proxying
  proxying :multi, :zrange, :zrem, :zadd, :zremrangebyrank, :zcard, :exists?, :del

  attr_accessor :typed
  attr_reader :limit

  def elements
    strings_to_types(zrange(0, -1) || [], typed)
  end
  alias to_a elements

  def remove(*elements)
    zrem(types_to_strings(elements, typed))
  end

  def prepend(elements)
    insert(elements, prepending: true)
  end

  def append(elements)
    insert(elements)
  end
  alias << append

  def limit=(limit)
    raise "Limit must be greater than 0" if limit && limit <= 0

    @limit = limit
  end

  private
    def insert(elements, prepending: false)
      elements = Array(elements)
      return if elements.empty?

      elements_with_scores = types_to_strings(elements, typed).map.with_index do |element, index|
        score = generate_base_score(negative: prepending) + (index / 100000)

        [ score , element ]
      end

      multi do |pipeline|
        pipeline.zadd(elements_with_scores)
        trim(from_beginning: prepending, pipeline: pipeline)
      end
    end

    def generate_base_score(negative:)
      current_time = process_start_time + process_uptime

      negative ? -current_time : current_time
    end

    def process_start_time
      @process_start_time ||= redis.time.join(".").to_f - process_uptime
    end

    def process_uptime
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def trim(from_beginning:, pipeline:)
      return unless limit

      if from_beginning
        pipeline.zremrangebyrank(limit, -1)
      else
        pipeline.zremrangebyrank(0, -(limit + 1))
      end
    end
end