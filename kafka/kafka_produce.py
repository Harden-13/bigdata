from kafka import KafkaProducer
import time
import json
import msgpack

class Kpapp:
    def __init__(self,server:list):
        self.server = server
        self.producer = KafkaProducer(bootstrap_servers=self.server,compression_type='gzip')

    def send(self,topic,message=None):
        if not message:
            return
        start = time.time()
        if isinstance(message,str):
            message = message.encode('utf-8')
        if isinstance(message,dict):
            message = json.dumps(message).encode('utf-8')
            print(message)

        future = self.producer.send(topic,message)
        result = future.get(timeout=5)
        used = time.time() - start
        print('time used: {}'.format(used))
        return result


if __name__ == '__main__':
    kafka_server = ['192.168.10.10:9092', '192.168.10.11:9092', '192.168.10.12:9092']
    kpapp = Kpapp(kafka_server)
    print(kpapp.send('test','this a test app '))
    print(kpapp.send('test',{'name':'kobe'}))