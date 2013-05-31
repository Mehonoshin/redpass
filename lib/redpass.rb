require 'net/http'
require 'net/https'
require "redpass/exception"

class Redpass
  API_PATH = '/transfer/single/'
  API_HOST = 'api.redpass.com'
  API_PORT = '443'

  SUCCESS_CODE = "1"
  RESPONSE_CODES = {
    "101" => "invalid_secure_password",
    "102" => "invalid_account_type",
    "103" => "not_enough_funds",
    "104" => "blocked_dst_account",
    "106" => "src_account_inactive",
    "107" => "account_does_not_exist",
    "108" => "invalid_amount",
    "114" => "incomes_disabled_on_dst_account",
    "121" => "dst_account_inactive",
    "123" => "transaction_expired"
  }

  def method
  end

  def self.transfer_funds(email, api_secret, options)
    redpass_api = self.new(email, api_secret, options)
    redpass_api.pay
  end

  def initialize(password, api_secret, options)
    @password, @api_secret, @options = ActiveSupport::Base64.encode64(password), api_secret, options
  end

  def pay
    code = get_response_code(api_call_result.body)
    if code == SUCCESS_CODE
      true
    else
      raise RedpassException, RESPONSE_CODES[code]
    end
  end

  private

  def api_call_result
    http = Net::HTTP.new(API_HOST, API_PORT)
    http.use_ssl = true
    http.post(API_PATH, data_string, headers)
  end

  def prepare_data_hash
    {
      :account_id => @options[:from],
      :to_email => @options[:to],
      :pass => @password,
      :currency => @options[:currency], 
      :amount => @options[:amount],
      :descriptor => "#{@options[:id]} #{@options[:domain]}",
      :reference_id => Time.now.to_i,
      :format => "JSON"
    }
  end

  def data_string
    data_hash = prepare_data_hash
    data_hash[:hash] = count_key(data_hash)
    "account_id=#{data_hash[:account_id]}&to_email=#{data_hash[:to_email]}&pass=#{data_hash[:pass]}&otp=#{data_hash[:otp]}&currency=#{data_hash[:currency]}&amount=#{data_hash[:amount]}&descriptor=#{data_hash[:descriptor]}&reference_id=#{data_hash[:reference_id]}&format=#{data_hash[:format]}&hash=#{data_hash[:hash]}"
  end

  def headers
    {'Content-Type' => 'application/x-www-form-urlencoded'}
  end

  def count_key(data_hash)
    raw_hash = "#{data_hash[:account_id]}#{data_hash[:to_email]}#{data_hash[:pass]}#{data_hash[:otp]}#{data_hash[:currency]}#{data_hash[:amount]}#{data_hash[:descriptor]}#{data_hash[:reference_id]}#{data_hash[:format]}"
    api_hash(raw_hash)
  end

  def api_hash(raw)
    Digest::MD5.hexdigest(raw + @api_secret)
  end

  def get_response_code(result)
    begin
      transaction_result = JSON.parse(result)
    rescue
      raise RedpassException, "empty_result"
    end
    transaction_result["Response_Code"] || transaction_result["code"]
  end

end

