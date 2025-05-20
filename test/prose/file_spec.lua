local File = require("prose.core.file")
local util = require("prose.core.utils")
local async = require("plenary.async")

describe("File.new()", function()
  it("should be able to be initialize directly", function()
    local file = File.new("FOO", { "foo", "foos" }, { "bar" })
    assert.is_true(File.is_file_obj(file))
  end)
end)

describe("File.from_file()", function()
  it("should work from a file", function()
    local file = File.from_file("test/fixtures/files/foo.md")
    assert.equals(file:fname(), "foo.md")
    assert.is_true(file.has_frontmatter)
    assert(#file.tags == 0)
  end)

  it("should work from a file w/o frontmatter", function()
    local file = File.from_file("test/fixtures/files/file_without_frontmatter.md")
    assert.equals(#file.tags, 0)
    assert.is_not(file:fname(), nil)
    assert.is_false(file.has_frontmatter)
  end)

  it("should collect additional frontmatter metadata", function()
    local file = File.from_file("test/fixtures/files/file_with_additional_metadata.md")
    assert.is_not(file.metadata, nil)
    assert.equals(file.metadata.foo, "bar")
    assert.equals(
      table.concat(file:frontmatter_lines(), "\n"),
      table.concat({
        "---",
        "tags: []",
        "foo: bar",
        "---",
      }, "\n")
    )
    file:save({ path = "./test/fixtures/files/file_with_additional_metadata_saved.md" })
  end)

  it("should be able to be read frontmatter that's formatted differently", function()
    local file = File.from_file("test/fixtures/files/file_with_different_frontmatter_format.md")
    assert.is_not(file.metadata, nil)
  end)
end)

describe("File.from_file_async()", function()
  it("should work from a file", function()
    async.util.block_on(function()
      local file = File.from_file_async("test/fixtures/files/foo.md")
      assert.equals(file:fname(), "foo.md")
      assert.is_true(file.has_frontmatter)
      assert(#file.tags == 0)
    end, 1000)
  end)
end)

describe("File.save()", function()
  it("should be able to save to file", function()
    local file = File.from_file("test/fixtures/files/foo.md")
    file:save({ path = "./test/fixtures/files/foo_bar.md" })
  end)

  it("should be able to save a file w/o frontmatter", function()
    local file = File.from_file("test/fixtures/files/file_without_frontmatter.md")
    file:save({ path = "./test/fixtures/files/file_without_frontmatter_saved.md" })
  end)
end)

describe("File._is_frontmatter_boundary()", function()
  it("should be able to find a frontmatter boundary", function()
    assert.is_true(File._is_frontmatter_boundary("---"))
    assert.is_true(File._is_frontmatter_boundary("----"))
  end)
end)
