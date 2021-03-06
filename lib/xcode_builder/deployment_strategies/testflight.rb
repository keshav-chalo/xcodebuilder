require 'rest_client'
require 'json'
require 'tmpdir'
require 'fileutils'

module XcodeBuilder
  module DeploymentStrategies
    class TestFlight < Strategy
      include Rake::DSL
      include FileUtils
      ENDPOINT = "https://testflightapp.com/api/builds.json"
      
      def extended_configuration_for_strategy
        proc do
          def generate_release_notes(&block)
            self.release_notes = block if block
          end
        end
      end
      
      def deploy
        release_notes = get_notes
        payload = {
          :api_token          => @configuration.api_token,
          :team_token         => @configuration.team_token,
          :file               => File.new(@configuration.ipa_path, 'rb'),
          :notes              => release_notes,
          :distribution_lists => (@configuration.distribution_lists || []).join(","),
          :notify             => @configuration.notify || false,
          :replace            => @configuration.replace || false
        }
        
        if @configuration.upload_dsym then
          payload[:dsym] = File.new(@configuration.dsym_path, 'rb')
        end

        if @configuration.verbose
          puts "ipa path: #{@configuration.ipa_path}"
          puts "release notes: #{release_notes}"
        end
        
        if @configuration.dry_run 
          puts '** Dry Run - No action here! **'
          return
        end
        
        print "Uploading build to TestFlight..."        
        
        statusCode = 0
        begin
          response = RestClient.post(ENDPOINT, payload, :accept => :json)
          statusCode = response.code
        rescue => e
          puts "TestFlight upload failed with exception:\n#{e}Response\n#{e.response}"
        end
        
        if (statusCode == 201) || (statusCode == 200)
          puts "Done."

        end
      end
      
      private
      
      def get_notes
        notes = @configuration.release_notes_text
        notes || get_notes_using_editor || get_notes_using_prompt
      end
      
      def get_notes_using_editor
        return unless (editor = ENV["EDITOR"])

        dir = Dir.mktmpdir
        begin
          filepath = "#{dir}/release_notes"
          system("#{editor} #{filepath}")
          @configuration.release_notes = File.read(filepath)
        ensure
          rm_rf(dir)
        end
      end
      
      def get_notes_using_prompt
        puts "Enter the release notes for this build (hit enter twice when done):\n"
        @configuration.release_notes = gets_until_match(/\n{2}$/).strip
      end
      
      def gets_until_match(pattern, string = "")
        if (string += STDIN.gets) =~ pattern
          string
        else
          gets_until_match(pattern, string)
        end
      end
    end
  end
end
