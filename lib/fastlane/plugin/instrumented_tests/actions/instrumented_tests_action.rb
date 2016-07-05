require 'open3'
require 'tempfile'

module Fastlane
  module Actions
    module SharedValues
    end

    class InstrumentedTestsAction < Action
      def self.run(params)
        setup_parameters(params)
        begin
          # Set up params
          delete_old_emulators(params)
          create_emulator(params)
          start_emulator(params)

          begin
            wait_emulator_boot(params)
            execute_gradle(params)
          ensure
            stop_emulator(params)
          end
        ensure
          @file.close
          @file.unlink
        end
      end

      def self.setup_parameters(params)
        # port must be an even integer number between 5554 and 5680
        params[:avd_port]=Random.rand(50)*2+5580 if params[:avd_port].nil?

        @android_serial="emulator-#{params[:avd_port]}"
        # maybe create this in a way that the creation and destruction are in the same method
        @file = Tempfile.new('emulator_output')
      end

      def self.delete_old_emulators(params)
        devices = `#{params[:sdk_path]}/tools/android list avd`.chomp

        # Delete avd if one already exists for clean state.
        unless devices.match(/#{params[:avd_name]}/).nil?
          Action.sh("#{params[:sdk_path]}/tools/android delete avd -n #{params[:avd_name]}")
        end
      end

      def self.create_emulator(params)
        avd_name = "--name \"#{params[:avd_name]}\""
        target_id = "--target #{params[:target_id]}"
        avd_options = params[:avd_options] unless params[:avd_options].nil?
        avd_abi = "--abi #{params[:avd_abi]}" unless params[:avd_abi].nil?
        avd_tag = "--tag #{params[:avd_tag]}" unless params[:avd_tag].nil?
        create_avd = ["#{params[:sdk_path]}/tools/android", "create avd", avd_name, target_id, avd_abi, avd_tag, avd_options].join(" ")

        UI.important("Creating AVD...")
        Action.sh(create_avd)
      end

      def self.start_emulator(params)
        UI.important("Starting AVD...")
        start_avd = ["#{params[:sdk_path]}/tools/emulator", "-avd #{params[:avd_name]}", "-gpu on -no-boot-anim -port #{params[:avd_port]} &>#{@file.path} &"]
        Action.sh(start_avd)
      end

      def self.wait_emulator_boot(params)
        UI.important("Waiting for emulator to finish booting... May take a few minutes...")
        adb = Helper::AdbHelper.new(adb_path: "#{params[:sdk_path]}/platform-tools/adb")
        loop do
          boot_complete_cmd = "ANDROID_SERIAL=#{@android_serial} #{params[:sdk_path]}/platform-tools/adb shell getprop sys.boot_completed" 
          stdout, _stdeerr, _status = Open3.capture3(boot_complete_cmd)

          if stdout.strip == "1"
            UI.success("Emulator Booted!")
            break
          end
        end
      end

      def self.execute_gradle(params)
        Fastlane::Actions::GradleAction.run(task: params[:task], flags: params[:flags], project_dir: params[:project_dir], 
          serial: @android_serial, print_command: true, print_command_output: true)
      end

      def self.stop_emulator(params)
        UI.important("Shutting down emulator...")
        adb = Helper::AdbHelper.new(adb_path: "#{params[:sdk_path]}/platform-tools/adb")
        adb.trigger(command: "emu kill", serial: @android_serial)

        UI.success("Deleting emulator...")
        Action.sh("#{params[:sdk_path]}/tools/android delete avd -n #{params[:avd_name]}")
      end

      def self.description
        "Run android instrumented tests via a gradle command againts a newly created avd"
      end

      def self.details
        [
          "Instrumented tests need a emulator or real device to execute against.",
          "This action will check for a specific avd and created, wait for full boot,",
          "run gradle command, then deleted that avd on each run."
        ].join("\n")
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :avd_name,
                                       env_name: "AVD_NAME",
                                       description: "Name of the avd to be created",
                                       is_string: true,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :target_id,
                                       env_name: "TARGET_ID",
                                       description: "Target id of the avd to be created, get list of installed target by running command 'android list targets'",
                                       is_string: true,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :avd_options,
                                       env_name: "AVD_OPTIONS",
                                       description: "Other avd options in the form of a <option>=<value> list, i.e \"--scale 96dpi --dpi-device 160\"",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_abi,
                                       env_name: "AVD_ABI",
                                       description: "The ABI to use for the AVD. The default is to auto-select the ABI if the platform has only one ABI for its system images",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_tag,
                                       env_name: "AVD_TAG",
                                       description: "The sys-img tag to use for the AVD. The default is to auto-select if the platform has only one tag for its system images",
                                       is_string: true,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :avd_port,
                                       env_name: "AVD_PORT",
                                       description: "The port used for communication with the emulator. If not set it is randomly selected",
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :sdk_path,
                                       env_name: "ANDROID_HOME",
                                       description: "The path to your android sdk directory",
                                       is_string: true,
                                       default_value: ENV['ANDROID_HOME'],
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :flags,
                                       env_name: "FL_GRADLE_FLAGS",
                                       description: "All parameter flags you want to pass to the gradle command, e.g. `--exitcode --xml file.xml`",
                                       optional: true,
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :task,
                                       env_name: "FL_GRADLE_TASK",
                                       description: "The gradle task you want to execute",
                                       is_string: true,
                                       optional: true,
                                       default_value: "connectedCheck"),
          FastlaneCore::ConfigItem.new(key: :project_dir,
                                       env_name: 'FL_GRADLE_PROJECT_DIR',
                                       description: 'The root directory of the gradle project. Defaults to `.`',
                                       default_value: '.',
                                       is_string: true)
        ]
      end

      def self.return_value
        "The output from the test execution."
      end

      def self.authors
        ["joshrlesch"]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
