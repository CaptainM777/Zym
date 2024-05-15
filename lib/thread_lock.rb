# Basic class used to block a thread from continuing until the lock is released (in a separate thread);
# uses mutexes internally
class ThreadLock
  # Initializes a lock in an open state
  def initialize
    @mutex = Mutex.new
    @cv = ConditionVariable.new
    @closed = false
  end

  # Closes the lock, blocking the thread until the lock is released
  def close
    raise 'This lock is already closed!' if @closed
    @closed = true
    @mutex.synchronize { @cv.wait(@mutex) }
    nil
  end

  # Opens the lock, unblocking any locked threads
  def open
    raise 'This lock is already open!' unless @closed
    @closed = false
    @cv.signal
    nil
  end
  alias_method :release, :open

  # Returns whether the lock is currently closed
  # @return [Boolean] whether the lock is currently closed
  def closed?
    @closed
  end
end