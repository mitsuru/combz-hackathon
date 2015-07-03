require 'csv'
require 'ostruct'
require 'pp'

class Fixnum
  def format
    to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
  end
end

class Calc
  def initialize(capsize=8)
    @averages = {}
    @capped = []
    @capsize = capsize
  end

  def calc(stock)
    @capped.push stock
    @capped.shift if @capped.size > @capsize
    return if @capped.size < @capsize

    sum = @capped.inject({}) { |a,b|
      a['open'] ||= 0
      a['open'] += b.open
      a
    }
    sum['open'] / @capsize
  end
end

class Position
  attr_accessor :money, :volume, :iv, :initial

  def initialize(money = 10000000)
    @initial = money
    @money = money
    @stocks = []
    @volume = 0
    @iv = 0
  end

  def ask(price, volume)
    operation(1, price, volume)
  end

  def bid(price, volume)
    operation(-1, price, volume)
  end

  def operation(op, price, volume)
    @stocks << OpenStruct.new(op: op, price: price, volume: volume)
    @money  -= price * volume * op
    @volume += volume * op
    @iv += price * volume * op
  end

  def sum
    price = 0
    @stocks.each do |stock|
      price += stock.price * stock.volume * stock.op
    end
    price
  end
end

def optimize(span)
  calc = Calc.new(span)
  position = Position.new

  CSV.open('7203.sort.csv') do |csv|
    prev = nil
    pstock = nil
    csv.each do |row|
      stock = OpenStruct.new
      stock.day = Date.parse(row[0])
      stock.open = row[1].to_i
      stock.high = row[2].to_i
      stock.low  = row[3].to_i
      stock.close = row[4].to_i
      stock.volume = row[5].to_i

      avg = calc.calc(stock)
      prev = avg
      next if avg.nil? or prev.nil?

      skip = false
      if skip
        # nothing
      elsif prev < stock.open
        position.ask(stock.open, 100)
      else
        position.bid(stock.open, 100)
      end
      pstock = stock
    end
    
    # 精算
    position.bid(pstock.close, position.volume)

    result = {
      'span'       => span,
      '残株数'     => position.volume,
      '残時価総額' => (pstock.close * position.volume),
      '現金残'     => position.money,
      '利益'       => position.money - position.initial
    }
  end
end

def main
  results = []
  max = 3
  3.upto(100) do |i|
    res = optimize(i)
    pp res
    results << res
  end

  puts "**********************"
  pp results.max { |a,b| a['現金残'] <=> b['現金残'] }
end

main
