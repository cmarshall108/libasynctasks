# libasynctasks

A framework built for fast, lightweight, dynamic concurrency. In order to achieve such,
we must understand how the task management system works. Each task has a function in which is called
by the TaskManager (provided the given arguments, etc...) these tasks run on TaskSchedulers (
which are a pool of threads). Tasks run in this order in attempt to achieve fast, efficient concurrency.
Implementing ```async/await``` functionality is planned and will work like the following:

```python

async def some_other_func():
    # do some random math for example...
    a = 5
    a = a ** 100
    a ^= 50
    print ('some_other_func', a)

async def test_func(task):
    await some_other_func()
    return task.cont

task_1 = task_manager.add_task('task_1', test_func)
```

This will allow you to achieve optimal performance fully taking advantage
of Python3's ```async/await```. libasynctasks is backwards compatible with Python2, with this being said ```async/await``` is not supported in Python2 and will most likely never be... However, there is a potential solution for such, this involves Python2's generators which are created by the ```yield``` keyword; this is still in debate...

# Examples

## Using continued tasks
```python
from libasynctasks import TaskManager


def test_task_1(task):
    print ('test_task_1', 'ran')
    return task.cont

def test_task_2(task):
    print ('test_task_2', 'ran')
    return task.cont

def test_task_3(task):
    print ('test_task_3', 'ran')
    return task.cont

def test_task_4(task):
    print ('test_task_4', 'ran')
    return task.cont

task_manager = TaskManager()

task_1 = task_manager.add_task('task_1', test_task_1)
task_2 = task_manager.add_task('task_2', test_task_2)
task_3 = task_manager.add_task('task_3', test_task_3)
task_4 = task_manager.add_task('task_4', test_task_4)

print (task_1)
print (task_2)
print (task_3)
print (task_4)

task_manager.run() # blocking
```

## Using delayed tasks
```python
from libasynctasks import TaskManager


def test_task_1(task):
    print ('test_task_1', 'ran')
    return task.wait

def test_task_2(task):
    print ('test_task_2', 'ran')
    return task.wait

def test_task_3(task):
    print ('test_task_3', 'ran')
    return task.wait

def test_task_4(task):
    print ('test_task_4', 'ran')
    return task.wait

task_manager = TaskManager()

task_1 = task_manager.add_task('task_1', test_task_1, delay=10)
task_2 = task_manager.add_task('task_2', test_task_2, delay=10)
task_3 = task_manager.add_task('task_3', test_task_3, delay=10)
task_4 = task_manager.add_task('task_4', test_task_4, delay=10)

print (task_1)
print (task_2)
print (task_3)
print (task_4)

task_manager.run() # blocking
```

# License

libasynctasks is licensed under the "
BSD 3-Clause License" for more info, refer to the [LICENSE](LICENSE) file.
