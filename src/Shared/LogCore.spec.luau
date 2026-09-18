return function()
	local LogCore = require(script.Parent.LogCore)

	local function reset()
		LogCore.ClearSinks()
		LogCore.SetGlobalMinLevel("Info")
	end

	describe("LogCore", function()
		it("emits structured entries to sinks", function()
			reset()

			local entries = {}
			LogCore.AddSink({
				Name = "Memory",
				Write = function(entry)
					table.insert(entries, entry)
				end,
			})

			LogCore.Info("Round started", { RoundId = 12 })

			expect(#entries).to.equal(1)
			expect(entries[1].Level).to.equal("Info")
			expect(entries[1].Message).to.equal("Round started")
			expect(entries[1].Context.RoundId).to.equal(12)
			expect(entries[1].Context.Level).to.equal("Info")
			expect(typeof(entries[1].Timestamp)).to.equal("number")
		end)

		it("filters with global, logger, and sink minimum levels", function()
			reset()

			local entries = {}
			LogCore.SetGlobalMinLevel("Warn")
			LogCore.AddSink({
				Name = "ErrorsOnly",
				MinLevel = "Error",
				Write = function(entry)
					table.insert(entries, entry)
				end,
			})

			LogCore.Info("hidden")
			LogCore.Warn("hidden by sink")
			LogCore.Error("visible")

			local verboseLogger = LogCore.new({
				minLevel = "Verbose",
			})

			verboseLogger.Debug("hidden by sink")
			verboseLogger.Error("also visible")

			expect(#entries).to.equal(2)
			expect(entries[1].Message).to.equal("visible")
			expect(entries[2].Message).to.equal("also visible")
		end)

		it("merges context for child loggers without mutating the parent context", function()
			reset()

			local entries = {}
			LogCore.AddSink({
				Write = function(entry)
					table.insert(entries, entry)
				end,
			})

			local baseContext = {
				Service = "Match",
				Shard = "A",
			}
			local logger = LogCore.new({
				defaultContext = baseContext,
			})
			local child = logger:WithContext({
				Shard = "B",
				RequestId = "abc",
			})

			child.Info("child", { RequestId = "def" })
			logger.Info("parent")

			expect(entries[1].Context.Service).to.equal("Match")
			expect(entries[1].Context.Shard).to.equal("B")
			expect(entries[1].Context.RequestId).to.equal("def")
			expect(entries[2].Context.Shard).to.equal("A")
			expect(baseContext.Shard).to.equal("A")
		end)

		it("adds, removes, clears, and returns sinks defensively", function()
			reset()

			local firstCount = 0
			local secondCount = 0
			local firstSink = {
				Name = "First",
				Write = function()
					firstCount += 1
				end,
			}
			local secondSink = {
				Name = "Second",
				Write = function()
					secondCount += 1
				end,
			}

			LogCore.AddSink(firstSink)
			LogCore.AddSink(secondSink)

			local sinks = LogCore.GetSinks()
			table.clear(sinks)

			LogCore.Info("before remove")
			expect(firstCount).to.equal(1)
			expect(secondCount).to.equal(1)

			expect(LogCore.RemoveSink("First")).to.equal(true)
			expect(LogCore.RemoveSink("Missing")).to.equal(false)

			LogCore.Info("after remove")
			expect(firstCount).to.equal(1)
			expect(secondCount).to.equal(2)

			LogCore.ClearSinks()
			LogCore.Info("after clear")
			expect(secondCount).to.equal(2)
		end)

		it("rejects invalid log levels", function()
			reset()

			expect(function()
				LogCore.Log("Trace" :: any, "invalid")
			end).to.throw()

			expect(function()
				LogCore.AddSink({
					MinLevel = "Trace" :: any,
					Write = function() end,
				})
			end).to.throw()
		end)

		it("writes fatal entries before raising", function()
			reset()

			local entries = {}
			LogCore.AddSink({
				Write = function(entry)
					table.insert(entries, entry)
				end,
			})

			expect(function()
				LogCore.Fatal("boom")
			end).to.throw()

			expect(#entries).to.equal(1)
			expect(entries[1].Level).to.equal("Fatal")
			expect(entries[1].Message).to.equal("boom")
		end)
	end)
end
