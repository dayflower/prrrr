require 'openssl'
require 'securerandom'
require 'base64'
require 'json'

module Prrrr
  module Util
    class << self
      def encrypt(password, data)
        salt = SecureRandom.random_bytes(8)

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.encrypt

        cipher.key, cipher.iv = generate_key_iv(cipher, password, salt)
        cipher.auth_data = ''

        binary = JSON.generate(data).force_encoding('ASCII-8BIT')
        encrypted = cipher.update(binary) + cipher.final
        tag = cipher.auth_tag

        Base64.urlsafe_encode64(salt + encrypted + tag)
      end

      def decrypt(password, data)
        return nil if data.nil?
        binary = Base64.urlsafe_decode64(data)
        salt = binary[0, 8]
        tag = binary[-16, 16]
        encrypted = binary[8...-16]

        cipher = OpenSSL::Cipher.new('aes-256-gcm')
        cipher.decrypt

        cipher.key, cipher.iv = generate_key_iv(cipher, password, salt)
        cipher.auth_data = ''
        cipher.auth_tag = tag

        begin
          decrypted = cipher.update(encrypted) + cipher.final
        rescue OpenSSL::Cipher::CipherError
          return nil
        end

        JSON.parse(decrypted.dup.force_encoding('UTF-8'), symbolize_names: true)
      end

      private

      def generate_key_iv(cipher, password, salt)
        key_iv = OpenSSL::PKCS5.pbkdf2_hmac(password, salt, 1974, cipher.key_len + cipher.iv_len, 'sha256')
        key = key_iv[0, cipher.key_len]
        iv = key_iv[cipher.key_len, cipher.iv_len]
        return key, iv
      end
    end
  end
end
