describe Fastlane::Actions::InstrumentedTestsAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The instrumented_tests plugin is working!")

      Fastlane::Actions::InstrumentedTestsAction.run(nil)
    end
  end
end
