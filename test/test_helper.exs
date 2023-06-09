Logger.configure(level: :warn)

Application.ensure_all_started(:logger)

ExUnit.start()
