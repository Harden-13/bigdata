##### django-celery

```
pip install django-celery==3.2.2
备注
django-celery: 3.2.2;   celery: 3.1.26.post2;  redis: 2.10.6; django: 2.0
```

##### celery configuration

```
import djcelery
from datetime import timedelta

# flower : python manager.py celery flower
# django-celery: 3.2.2;   celery: 3.1.26.post2;  redis: 2.10.6

djcelery.setup_loader()
CELERY_IMPORTS = (
    'cmdb.tasks.asset',
)

CELERY_QUEUES = {
    'timing_tasks': {
        'exchange': 'timing_tasks',
        'exchange_type': 'direct',
        'binding_key': 'timing_tasks'
    },
    'default_tasks': {
        'exchange': 'default_tasks',
        'exchange_type': 'direct',
        'binding_key': 'default_tasks'
    }
}

# 默认使用的队列
CELERY_DEFAULT_QUEUE = 'default_tasks'

# 防止死锁
CELERY_FORCE_EXECV = True

# 设置并发的worker数量
CELERY_CONCURRENCY = 8

# 允许重试
CELERY_ACKS_LATE = True

# 每个worker最多执行100个任务被销毁，防止内存泄露
CELERY_MAX_TASKS_PER_CHILD = 100

# 单个任务执行的最大时间6min
CELERY_TASK_TIME_LIMIT = 12 * 30

CELERYBEAT_SCHEDULE = {
    'task1': {
        # task任务类里面的name, 也可以写绝对路径cmdb.tasks.asset
        'task': 'test_task',
        'schedule': timedelta(seconds=10),
        # 'args'
        'options': {
            'queue': 'timing_tasks'
        }
    }
}
```

##### cmdb.tasks.asset

```
from celery.task import Task

class CourseTask(Task):
    name = 'test_task'

    def run(self, *args, **kwargs):
        print('start course task')
```

##### cmdb.views.tasks

```
from celery import task
from ..tasks.asset import CourseTask
from django.http import HttpRequest, JsonResponse

def do(request: HttpRequest):
    CourseTask.delay()     # 此处指定queue也可以
    return JsonResponse({'result': 'ok'})
```

##### urls

```
url(r'^task$', do),
```

##### settings

```
# celery
from conf.celeryconfig import *

BROKER_BACKEND = 'redis'

BROKER_URL = 'redis://localhost:6379/0'

CELERY_RESULT_BACKEND = 'redis://localhost:6379/1'

```

##### 启动 celery work, celery beat ,django

```
python manage.py celery beat --loglevel=info
python manage.py  celery worker --loglevel=info
python manage.py  runserver 0.0.0.0:8000
python manage.py flower		# 读取django里面的设置
```

##### flower

```
pip install flower==0.9
celery flower --address=0.0.0.0 --port=5555 --broker=redis -basic_auth=admin:admin
```

