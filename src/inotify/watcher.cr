module Inotify
  class Watcher
    @enabled : Bool = false

    def initialize(@path : String, @poll_interval : UInt32 = 1_u32, &block : Event ->)
      @fd = LibInotify.init LibC::O_NONBLOCK
      raise "inotify init failed" if @fd < 0
      # puts "inotify init"
      # flags = LibC.fcntl(@fd, LibC::F_GETFL, 0)
      # LibC.fcntl(@fd, LibC::F_SETFL, flags | LibC::O_NONBLOCK)

      @wd = LibInotify.add_watch(@fd, @path, LibInotify::IN_MODIFY | LibInotify::IN_CREATE | LibInotify::IN_DELETE)
      raise "inotify add_watch failed" if @wd == -1
      # puts "inotify add_watch"

      @on_event_callback = block
      enable
    end

    def enable
      unless @enabled
        @enabled = true
        spawn watch
      end
    end

    def disable
      @enabled = false
    end

    private def watch
      pos = 0
      while @enabled
        slice = Slice(UInt8).new(LibInotify::BUF_LEN)
        bytes_read = LibC.read(@fd, slice.pointer(slice.size).as(Void*), slice.size)
        if bytes_read > 0
          while pos < bytes_read
            sub_slice = slice + pos
            event_ptr = sub_slice.pointer(sub_slice.size).as(LibInotify::Event*)

            slice_event_name = sub_slice[16, event_ptr.value.len]
            event_name = String.new(slice_event_name.pointer(slice_event_name.size).as(LibC::Char*))

            @on_event_callback.call(Event.new(event_name, File.join(@path, event_name), event_ptr.value.mask, event_ptr.value.cookie))
            pos += 16 + event_ptr.value.len
          end
          pos = 0
        end
        sleep @poll_interval
      end
    end

    private def unwatch
      LibInotify.rm_watch(@fd, @wd)
    end

    def finalize
      LibInotify.rm_watch(@fd, @wd)
      LibC.close(@fd)
    end
  end
end