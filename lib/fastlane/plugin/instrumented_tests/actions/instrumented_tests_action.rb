require 'open3'
require 'tempfile'

module Fastlane
  module Actions
    module SharedValues
    end

    class InstrumentedTestsAction < Action
      def self.run(params)
        setup_parameters(params)
        delete_old_emulators(params)
        begin
          begin
            create_emulator(params)
            start_emulator(params)

            wait_emulator_boot(params)
            execute_gradle(params)
          ensure
            stop_emulator(params)
          end

        rescue Exception => e
          print_emulator_output(params)
          raise e
        ensure
          close_emulator_streams(params)
        end
      end

      def self.setup_parameters(params)
        # port must be an even integer number between 5554 and 5680
        params[:avd_port]=Random.rand(15)*2+5554 if params[:avd_port].nil?
        raise ":avd_port must be at least 5554" if params[:avd_port]<5554
        raise ":avd_port must be lower than 5584" if params[:avd_port]>5584
        raise ":avd_port must be an even number" if params[:avd_port]%2 != 0

        @android_serial="emulator-#{params[:avd_port]}"
      end

      def self.delete_old_emulators(params)
        devices = `#{params[:sdk_path]}/tools/android list avd`.chomp

        unless devices.match(/#{params[:avd_name]}/).nil?
          Action.sh("#{params[:sdk_path]}/tools/android delete avd -n #{params[:avd_name]}")
        end
      end

      def self.create_emulator(params)
        avd_name = "--name '#{params[:avd_name]}'"
        avd_package = "--package #{params[:avd_package]}"
        avd_abi = "--abi #{params[:avd_abi]}"
        create_avd = ["echo no | #{params[:sdk_path]}/tools/bin/avdmanager", "create avd", avd_package, avd_name, avd_abi]
        UI.important("Creating AVD...")
        Action.sh(create_avd)
      end

      def self.start_emulator(params)
        UI.important("Starting AVD...")
        ui_args = "-gpu on"
        ui_args << " -no-window" if params[:avd_hide]
        ui_args << " " << params[:emulator_options] if params[:emulator_options] != nil
        start_avd = ["#{params[:sdk_path]}/tools/emulator", "-avd #{params[:avd_name]}", "#{ui_args}", "-port #{params[:avd_port]}" ].join(" ")

        UI.command(start_avd)
        stdin, @emulator_output, @emulator_thread = Open3.popen2e(start_avd)
        stdin.close
      end

      def self.wait_emulator_boot(params)
        timeout = Time.now + params[:boot_timeout]
        UI.important("Waiting for emulator to finish booting... May take a few minutes...")

        adb_path = "#{params[:sdk_path]}/platform-tools/adb"
        raise "Unable to find adb in #{adb_path}" unless File.file?(adb_path)
        loop do
          boot_complete_cmd = "ANDROID_SERIAL=#{@android_serial} #{adb_path} shell getprop sys.boot_completed" 
          stdout, _stdeerr, _status = Open3.capture3(boot_complete_cmd)

          if @emulator_thread != nil && (@emulator_thread.status == false || @emulator_thread.status == true)
            UI.error("Emulator unexpectedly quit!")
            raise "Emulator unexpectedly quit"
          end

          if (Time.now > timeout)
            UI.error("Waited #{params[:boot_timeout]} seconds for emulator to boot without success")
            raise "Emulator didn't boot"
          end

          if stdout.strip == "1"
            UI.success("Emulator Booted!")
            break
          end
          sleep(1)
        end
      end

      def self.stop_emulator(params)
        begin
          UI.important("Shutting down emulator...")
          adb = Helper::AdbHelper.new(adb_path: "#{params[:sdk_path]}/platform-tools/adb")
          adb.trigger(command: "emu kill", serial: @android_serial)
        rescue
          UI.message("Emulator is not listening for our commands...")
          UI.message("Current status of emulator process is: #{@emulator_thread.status}")

          if @emulator_thread != nil && @emulator_thread.status != true && @emulator_thread.status != false
            UI.important("Emulator still running... Killing PID #{@emulator_thread.pid}!")
            Process.kill("KILL", @emulator_thread.pid)
          end

        end

        UI.important("Deleting emulator...")
        Action.sh("#{params[:sdk_path]}/tools/android delete avd -n #{params[:avd_name]}")
      end

      def self.print_emulator_output(params)
        UI.error("Error while trying to execute instrumentation tests. Output from emulator:")
        @emulator_output.readlines.each do |line|
          UI.error(line.gsub(/\r|\n/, " "))
        end
      end

      def self.close_emulator_streams(params)
        @emulator_output.close
      end

      def self.execute_gradle(params)
        Fastlane::Actions::GradleAction.run(task: params[:task], flags: params[:flags], project_dir: params[:project_dir],
                                            serial: @android_serial, print_command: true, print_command_output: true)
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
          FastlaneCore::ConfigItem.new(key: :avd_abi,
                                       env_name: "AVD_ABI",
                                       description: "The ABI to use for the AVD (e.g. google_apis/x86)",
                                       is_string: true,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :avd_package,
                                       env_name: "AVD_PACKAGE",
                                       description: "Package path of the system image for this AVD (e.g. 'system-images;android-19;google_apis;x86')",
                                       is_string: true,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :avd_port,
                                       env_name: "AVD_PORT",
                                       description: "The port used for communication with the emulator. If not set it is randomly selected",
                                       is_string: false,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :boot_timeout,
                                       env_name: "BOOT_TIMEOUT",
                                       description: "Number of seconds to wait for the emulator to boot",
                                       is_string: false,
                                       optional: true,
                                       default_value: 500),
          FastlaneCore::ConfigItem.new(key: :emulator_options,
                                       env_name: "EMULATOR_OPTIONS",
                                       description: "Other options passed to the emulator command ('emulator -avd AVD_NAME ...')." +
                                           "Defaults are '-gpu on' when AVD_HIDE is false and '-no-window' otherwise. " +
                                           "For macs running the CI you might want to use '-no-audio -no-window'",
                                       is_string: true,
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
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :avd_hide,
                                       env_name: "AVD_HIDE",
                                       description: "Specifies whether the emulator should be hidden or not (defaults to true)",
                                       default_value: true,
                                       is_string: false,
                                       optional: true)
        ]
      end

      def self.return_value
        "The output from the test execution."
      end

      def self.authors
        ["joshrlesch", "lexxdark"]
      end

      def self.is_supported?(platform)
        platform == :android
      end
    end
  end
end
