require 'smarter_csv'
require 'set'
require 'pp'

module Logit
  class << self
    include Math

    INORM = 9 # normal index

    # The following are indices into the [n,j,t] keys
    # Note we actually swap the numerical position of J and T because
    # we also want to index [n, t] keys efficiently.
    N = 0
    T = 1
    J = 2

    def process(coefcsv = 'coef.csv', datacsv = 'data.csv')
      begin_load_time = Time.now
      coef = SmarterCSV.process(coefcsv).inject({}){|memo, row| memo[row[:n]] = row; memo }
      data = SmarterCSV.process(datacsv).inject({}){|memo, row| memo[[row[:n], row[:t], row[:j]]] = row; memo }
      begin_time = Time.now
      prob_ntj = compute_logit coef, data
      end_time = Time.now

      puts 'n,t,j,p'
      prob_ntj.map { |key, prob| key + [prob] }
      .each { |r| puts r.join(',') }
      $stderr.puts "Running time is #{end_time - begin_time}, data load time is #{begin_time - begin_load_time}"
    end

    def compute_logit(coef, data)
      ialpha = coef.first.last.keys
      .select{|s| /alpha/ =~ s}
      .inject({}){ |memo, s|
        tok = /asc_(\d+)/.match(s)
        memo[tok[1].to_i] = {coef: s, data: tok[0].to_sym}
        memo
      }
      ntkeys = data.keys.inject(Set.new){|memo, key|memo << [key[N], key[T]]}
      eutility = data.inject({}){|memo, keyrow|
        key, row = keyrow
        memo[key] = exp(((key[J] != INORM) ? coef[key[N]][ialpha[key[J]][:coef]] : 0 ) +
                            coef[key[N]][:beta] * row[:price])
        memo
      }
      sigma_nt = ntkeys.inject({}){|memo, nt| memo[nt] =
          (1..ialpha.keys.last).reduce(0){|rmemo, k|
            ntk = nt + [k]
            rmemo + ((eutility[ntk].nil?) ? 0 : eutility[ntk])
          }
        memo
      }
      prob_ntj = data.inject({}){|memo, (key, row)|
        memo[key] = eutility[key] / sigma_nt[key[N..T]]
        memo
      }
      prob_ntj
    end
  end
end
