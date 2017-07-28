require "./inotify/*"

module Inotify
  struct Event
    property name, path : String
    property mask, cookie : UInt32

    def initialize(@name : String, @path : String, @mask : UInt32, @cookie : UInt32)
    end
  end

  class Watcher
    def initialize(@path : String, &block : Event ->)
      @fd = LibInotify.init
      raise "inotify init failed" if @fd < 0

      @wd = LibInotify.add_watch(@fd, @path, LibInotify::IN_MODIFY | LibInotify::IN_CREATE | LibInotify::IN_DELETE)
      raise "inotify add_watch failed" if @wd == -1

      puts "Hello"
      @on_event_callback = block
      spawn watch
      Fiber.yield
    end

    private def watch
        loop do |i|
          slice = Slice(UInt8).new(LibInotify::BUF_LEN)
          bytes_read = LibC.read(@fd, slice.pointer(slice.size).as(Void*), slice.size)
          event_ptr = slice.pointer(slice.size).as(LibInotify::Event*)

          slice_event_name = slice[16, event_ptr.value.len]
          event_name = String.new(slice_event_name.pointer(slice_event_name.size).as(LibC::Char*))

          @on_event_callback.call(Event.new(event_name, File.join(@path, event_name), event_ptr.value.mask, event_ptr.value.cookie))
        end
    end

    def finalize
      LibInotify.rm_watch(@fd, @wd)
      LibC.close(@fd)
    end
  end
end
