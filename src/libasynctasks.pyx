"""
A framework built to make concurrency fast, simple and dynamic;
using the Task concept (and soon to support coroutines async/await...).
"""

import threading
import time
import collections

include "_threading.pyx"


ctypedef enum TaskResult:
    TASK_DONE,
    TASK_WAIT,
    TASK_CONT

ctypedef enum TaskUsage:
    TASK_USAGE_FULL = 100,
    TASK_USAGE_LOAD = 50,
    TASK_USAGE_LIGHT = 25


class TaskError(RuntimeError):
    """
    An task specific runtime error
    """


cdef class Task(object):
    """
    An object that represents work in which needs to be completed,
    in asynchronous form by a scheduler in the pool.
    """

    __slots__ = (
        '_name',
        '_delay',
        '_can_delay',
        '_timestamp',
        '_function',
        '_args',
        '_kwargs'
    )

    cdef str _name
    cdef float _delay
    cdef bint _can_delay

    # we have to define the timestamp as an object because,
    # defining it as a float causes the variable to become static...
    cdef object _timestamp

    cdef object _function
    cdef tuple _args
    cdef dict _kwargs

    def __init__(self, name, delay, function, *args, **kwargs):
        self._name = name

        self._delay = delay
        self._can_delay = False
        self._timestamp = self.get_timestamp()

        self._function = function
        self._args = args
        self._kwargs = kwargs

    @property
    def name(self):
        return self._name

    @name.setter
    def name(self, name):
        self._name = name

    @property
    def delay(self):
        return self._delay

    @delay.setter
    def delay(self, delay):
        self._delay = delay

    @property
    def can_delay(self):
        return self._can_delay

    @can_delay.setter
    def can_delay(self, can_delay):
        self._can_delay = can_delay

    @property
    def function(self):
        return self._function

    @function.setter
    def function(self, function):
        self._function = function

    @property
    def args(self):
        return self._args

    @args.setter
    def args(self, args):
        self._args = args

    @property
    def kwargs(self):
        return self._kwargs

    @kwargs.setter
    def kwargs(self, kwargs):
        self._kwargs = kwargs

    @property
    def done(self):
        """
        Define our @TASK_DONE variable from the @TaskResult enum...
        """

        return TASK_DONE

    @property
    def wait(self):
        """
        Define our @TASK_WAIT variable from the @TaskResult enum...
        """

        return TASK_WAIT

    @property
    def cont(self):
        """
        Define our @TASK_CONT variable from the @TaskResult enum...
        """

        return TASK_CONT

    cdef object get_timestamp(self):
        """
        Returns a epoch timestamp rounded to the nearest hundredth...
        """

        return round(time.time(), 2)

    def run(self):
        """
        Attempt to execute the function provided on initialization,
        returning it's result to the scheduler.
        """

        # check to see if we are able to run this task,
        # check against the last timestamp and our delay...
        if self._can_delay:
            if self.get_timestamp() - self._timestamp < self._delay:
                # seems we cannot yet run this function,
                # just return a cont so this task will be placed
                # back in our schedulers queue...
                return TASK_WAIT
            else:
                # update our current timestamp which will be the last
                # time we executed our function, this will restart the timer...
                self._timestamp = self.get_timestamp()

        return self._function(self, *self._args, **self._kwargs)

    def __del__(self):
        self._name = None

        self._delay = 0
        self._can_delay = False
        self._timestamp = 0

        self._function = None
        self._args = None
        self._kwargs = None

        super().__del__()


class TaskScheduler(threading.Thread):
    """
    An object that represents a scheduler for running pending tasks,
    this object also derrives from threading.Thread because it is a
    thread in the TaskManager pool...
    """

    __slots__ = (
        '_task_manager',
        '_mutex_lock',
        '_shutdown',
        '_task_queue'
    )

    def __init__(self, task_manager):
        self._task_manager = task_manager
        self._mutex_lock = threading.RLock()

        self._shutdown = False
        self._task_queue = collections.deque()

        super().__init__(target=self.__run)

    @property
    def name(self):
        return '%s-%s' % (self.__class__.__name__, id(self))

    @property
    def shutdown(self):
        return self._shutdown

    @shutdown.setter
    def shutdown(self, shutdown):
        self._shutdown = shutdown

    @property
    def task_queue(self):
        return self._task_queue

    @task_queue.setter
    def task_queue(self, task_queue):
        self._task_queue = task_queue

    def __cmp__(self, other_scheduler):
        """
        Compares the number of running tasks in our queue against the other
        scheduler's queue and returns the result...
        """

        return len(other_scheduler.task_queue) < len(self.task_queue)

    def _set_daemon(self):
        """
        Overrides the threading.Thread method, because we always
        want daemon set on our thread...
        """

        return True

    def has_task(self, task):
        """
        Returns true if the task is in the queue else false.
        """

        return task in self._task_queue

    def add_task(self, task):
        """
        Attemps to add the task object to the task queue...
        """

        if not isinstance(task, Task):
            raise TaskError('Attempted to add task of invalid type <%r>!' % task)

        if self.has_task(task):
            raise TaskError('Cannot add task <%s> task already exists!' % task.name)

        self._task_queue.append(task)

    def remove_task(self, task):
        """
        Attempts to remove the task object from the task queue...
        """

        if not self.has_task(task):
            raise TaskError('Cannot remove task <%s> task does not exist!' % task.name)

        self._task_queue.remove(task)

    def setup(self):
        """
        Sets up the task scheduler object, starting it's thread...
        """

        threading.Thread.start(self)

    def update(self):
        """
        Called to execute our current queued tasks in the task queue,
        handles the outcome of a task object by what it's function tells us to do...
        """

        # check to see if we have any pending tasks in
        # the queue. This usually will not be the case but for
        # a few milliseconds from the time between when we initialize
        # the class object and when we add the task to it...
        if not len(self._task_queue):
            return

        # retrieve a task object from the task queue,
        # then let's execute it and figure out what it wants
        # to be done with next...
        task = self._task_queue.popleft()
        result = task.run()

        # check the result against the valid result values,
        # if the value is anything other than wait, cont then we assume
        # the task has been completed and we remove it...
        if result == TASK_DONE:
            return
        elif result == TASK_WAIT:
            task.can_delay = True
            # since this task is delayed, we need to keep it on it's original
            # thread; otherwise our thread will be killed and the task will
            # float in oblivion forever...
            self._task_queue.append(task)
        elif result == TASK_CONT:
            task.can_delay = False
            # add this task back to the task manager's queue so it can
            # be ran on another thread if another one is available and has
            # even less currently running tasks on it...
            self._task_manager.task_queue.append(task)
        else:
            # check to see if we got any other result than what we
            # are expecting, tasks do not return values when they are called
            # like a normal function... So we should never expect this to be the case.
            raise TaskError('Got invalid result <%r> when running task <%s>!' % (
                result, task.name))

        # finally let's check to see if we have any tasks remaining
        # in the task queue, if we do not; then this means we have
        # served our purpose and is no longer needed...
        if not len(self._task_queue):
            self._shutdown = True
            return

    def __run(self):
        """
        The thread's mainloop entry point in which we will
        be doing the actual processing...
        """

        while not self._shutdown:
            # acquire the mutex lock so we don't change the queue
            # during it's iteration on the other thread...
            with self._mutex_lock:
                try:
                    self.update()
                except (KeyboardInterrupt, SystemExit):
                    break

            thread_wait()

        self._task_manager.remove_scheduler(self)

    def __del__(self):
        self._mutex_lock = None
        self._task_queue = None


cdef class TaskManager(object):
    """
    An object that manages the scheduler pool which contains multiple
    Task objects in which are executed in asynchronous form...
    """

    __slots__ = (
        '_schedulers',
        '_task_queue'
    )

    cdef dict _schedulers
    cdef object _task_queue

    def __init__(self):
        self._schedulers = {}
        self._task_queue = collections.deque()

    @property
    def scheduler_queue(self):
        return self._schedulers

    @scheduler_queue.setter
    def scheduler_queue(self, scheduler_queue):
        self._schedulers = scheduler_queue

    @property
    def task_queue(self):
        return self._task_queue

    @task_queue.setter
    def task_queue(self, task_queue):
        self._task_queue = task_queue

    def has_task(self, task):
        """
        Returns true if the task exists in the queue else false.
        """

        return task in self._queue

    def add_task(self, name, function, *args, **kwargs):
        """
        Creates a new task object specifying the provided arguments,
        then adds it to the queue...
        """

        if not callable(function):
            raise TaskError('Cannot add task <%s> with non callable function <%r>!' % (
                name, function))

        task = Task(name, kwargs.pop('delay', 0), function, *args, **kwargs)
        self._task_queue.append(task)

        return task

    def remove_task(self, task):
        """
        Attempts to remove the specified task object from the queue...
        """

        if not isinstance(task, Task):
            raise TaskError('Cannot remove task of invalid type <%r>!' % task)

        if not self.has_task(task.name):
            raise TaskError('Cannot remove task <%s> because it does not exist!' % task.name)

        self._task_queue.remove(task)
        del task

    def has_scheduler(self, scheduler_name):
        """
        Returns true if the scheduler exists in the queue else false.
        """

        return scheduler_name in self._schedulers

    def add_scheduler(self, scheduler):
        """
        Adds the scheduler object to the scheduler queue.
        """

        if not isinstance(scheduler, TaskScheduler):
            raise TaskError('Cannot add scheduler of invalid type <%r>!' % scheduler)

        if self.has_scheduler(scheduler.name):
            raise TaskError('Cannot add scheduler <%r> scheduler already exists!' % scheduler)

        self._schedulers[scheduler.name] = scheduler
        scheduler.setup()

    def remove_scheduler(self, scheduler):
        """
        Attempts to remove the scheduler object from the scheduler queue...
        """

        if not isinstance(scheduler, TaskScheduler):
            raise TaskError('Cannot remove scheduler of invalid type <%r>!' % scheduler)

        if not self.has_scheduler(scheduler.name):
            raise TaskError('Cannot remove scheduler <%r> scheduler does not exist!' % scheduler)

        del self._schedulers[scheduler.name]
        del scheduler

    cdef object get_available_scheduler(self):
        """
        Attempts to find an scheduler in the dictionary that has the least
        number of currently running tasks, if a scheduler is not found in the dictionary,
        a new scheduler object is created and returned...
        """

        # check to see if we have an available scheduler that has a lower
        # number of currently queued tasks than default constants specify...
        available_scheduler = None
        for scheduler in list(self._schedulers.values()):
            if len(scheduler.task_queue) > TASK_USAGE_LIGHT:
                continue

            available_scheduler = scheduler
            break

        # if a scheduler is not currently available, let's assume they are all full,
        # and create a new thread then add it to the pool.
        if not available_scheduler:
            available_scheduler = TaskScheduler(self)
            self.add_scheduler(available_scheduler)

        return available_scheduler

    cdef void update(self):
        """
        Manages the number of schedulers that are currently running,
        moves pending tasks to schedulers to be ran...
        """

        # check to see if there are any pending task objects
        # in the task queue before we attempt to retrieve any...
        if not len(self._task_queue):
            return

        # there are tasks in the queue, proceed to retrieve a
        # task object from the queue...
        task = self._task_queue.popleft()

        # get an available scheduler from the queue which has the least
        # number of currently running tasks...
        scheduler = self.get_available_scheduler()
        scheduler.add_task(task)

    def run(self):
        """
        Run the task manager's main loop, this is blocking in the main thread...
        """

        while True:
            try:
                self.update()
            except (KeyboardInterrupt, SystemExit):
                break

            thread_wait()

        self.destroy()

    def __del__(self):
        self._schedulers = None
        self._task_queue = None

        super().__del__()
