# libasynctasks

A framework built to make concurrency fast, simple and dynamic;
using the Task concept (and soon to support coroutines async/await...).

# Examples

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

task_manager.run()
```

# License

libasynctasks is licensed under the "
BSD 3-Clause License" for more info, refer to the [LICENSE](LICENSE) file.
