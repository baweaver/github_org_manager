# frozen_string_literal: true

RSpec.describe GithubOrgManager do
  it "has a version number" do
    expect(GithubOrgManager::VERSION).not_to be nil
  end

  # I'll add some tests to this later, for now it's
  # a more alpha proof of concept.
  it "does something useful" do
    expect(true).to eq(true)
  end
end
