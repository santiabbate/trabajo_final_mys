import socket
import messages_pb2
import matplotlib
import matplotlib.pyplot as plt

class InitError(Exception):
    def __init__(self, message):
        self.message = "Init Error:" + message
    pass

class AckError(Exception):
    def __init__(self, message):
        self.message = "Ack Error:" + message
    pass

class Generator:
    def __init__(self, ip, port):
        self.base_msg = messages_pb2.Base_msg()
        self.config = messages_pb2.Generator_Config_msg()
        self.control = messages_pb2.Base_msg()

        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(3)
        self.server_address = (ip, port)
        print('Connecting to {} port {}'.format(self.server_address[0],self.server_address[1]))
        try:
            self.sock.connect(self.server_address)
            self.connected = True
        except Exception as e:
            self.connected = False
            self.sock.close()
            raise InitError("Connect timeout")

    def enable_debug(self, val = True):
        self.config.debug_enabled = val

    def __send_config__(self):
        serial = self.__serialize_config__()
        self.sock.send(serial)
        input = self.sock.recv(100)
        retmsg = messages_pb2.Base_msg()
        retmsg.ParseFromString(input)
        if retmsg.ack.retval == messages_pb2.Ack_msg.BAD_CONFIG:
            raise AckError("Bad Config")

    def set_continuous_mode_constant_freq(self, freq_khz):
        self.config.mode = self.config.CONTINUOUS
        self.config.const_freq.freq_khz = freq_khz
        self.__send_config__()
    
    def set_continuous_mode_freq_mod(self, low_freq_khz, high_freq_khz, length_us):
        self.config.mode = self.config.CONTINUOUS
        self.config.freq_mod.low_freq_khz = low_freq_khz
        self.config.freq_mod.high_freq_khz = high_freq_khz
        self.config.freq_mod.length_us = length_us
        self.__send_config__()

    def set_continuous_mode_phase_mod(self, freq_khz, barker_seq_num, barker_subpulse_length_us):
        self.config.mode = self.config.CONTINUOUS
        self.config.phase_mod.freq_khz = freq_khz
        self.config.phase_mod.barker_seq_num = barker_seq_num
        self.config.phase_mod.barker_subpulse_length_us = barker_subpulse_length_us
        self.__send_config__()

    def set_pulsed_mode_constant_freq(self, period_us, pulse_length_us, freq_khz):
        self.config.mode = self.config.PULSED
        self.config.period_us = period_us
        self.config.pulse_length_us = pulse_length_us
        self.config.const_freq.freq_khz = freq_khz
        self.__send_config__()

    def set_pulsed_mode_freq_mod(self, period_us, pulse_length_us, low_freq_khz, high_freq_khz):
        self.config.mode = self.config.PULSED
        self.config.period_us = period_us
        self.config.pulse_length_us = pulse_length_us
        self.config.freq_mod.low_freq_khz = low_freq_khz
        self.config.freq_mod.high_freq_khz = high_freq_khz
        self.__send_config__()

    def set_pulsed_mode_phase_mod(self, period_us, pulse_length_us, freq_khz, barker_seq_num):
        self.config.mode = self.config.PULSED
        self.config.period_us = period_us
        self.config.pulse_length_us = pulse_length_us
        self.config.phase_mod.freq_khz = freq_khz
        self.config.phase_mod.barker_seq_num = barker_seq_num
        self.__send_config__()

    def __serialize_config__(self):
        self.base_msg.config.generator.CopyFrom(self.config)
        self.serial = self.base_msg.SerializeToString()
        return self.serial

    def start(self):
        self.control.control.command = self.control.control.START
        serial = self.control.SerializeToString()
        self.sock.send(serial)
        input = self.sock.recv(100)
        retmsg = messages_pb2.Base_msg()
        retmsg.ParseFromString(input)
        if retmsg.ack.retval == messages_pb2.Ack_msg.ACK:
            return True
        elif retmsg.ack.retval == messages_pb2.Ack_msg.NO_CONFIG:
            raise AckError("No Config")
        elif retmsg.ack.retval == messages_pb2.Ack_msg.BAD_COMMAND:
            raise AckError("Bad Command")
        
    def stop(self):
        self.control.control.command = self.control.control.STOP
        serial = self.control.SerializeToString()
        self.sock.send(serial)
        input = self.sock.recv(100)
        retmsg = messages_pb2.Base_msg()
        retmsg.ParseFromString(input)
        if retmsg.ack.retval == messages_pb2.Ack_msg.ACK:
            return True
        else:
            raise AckError("Stop Error")

    def trigger_debug(self):
        self.control.control.command = self.control.control.TRIG_DBG
        serial = self.control.SerializeToString()
        self.sock.send(serial)
        # self.sock.settimeout(0)
        fragments = []
        while True:
            try: 
                chunk = self.sock.recv(500000)
                fragments.append(chunk)
            except: 
                break
        input = b''.join(fragments)
        retmsg = messages_pb2.Debug_msg()
        try:
            retmsg.ParseFromString(input)
            self.i_samples = retmsg.i_samples
            self.q_samples = retmsg.q_samples
            self.num_samples = retmsg.num_samples
        except:
            raise AckError("Debug Error")
        # self.sock.settimeout(30)

        # if retmsg.ack.retval == messages_pb2.Ack_msg.ACK:
        #     return True
        # else:

    def dump_samples(self):
        with open("dump.txt","w+") as f: 
            for i in range(self.num_samples):
                f.write("%s,%s\n" % (self.i_samples[i], self.q_samples[i]))
            f.close()

    def plot_samples(self):
        if self.num_samples != 0:
            fig, ax = plt.subplots(2,1)
            ax[0].plot(range(self.num_samples), self.i_samples[0:self.num_samples])
            ax[1].plot(range(self.num_samples), self.q_samples[0:self.num_samples])
            plt.show()


def main():
    gen = Generator('192.168.1.10', 7)

    gen.enable_debug(True)

    gen.set_pulsed_mode_phase_mod(65, 10, 5643, 5)
    print(gen.config)

    gen.set_continuous_mode_constant_freq(5000)
    print(gen.config)

    gen.set_continuous_mode_freq_mod(1000,5000,150)
    print(gen.config)

    gen.set_continuous_mode_phase_mod(20000, 7, 5)
    print(gen.config)

    gen.set_pulsed_mode_constant_freq(150, 35, 3000)
    print(gen.config)

    gen.set_pulsed_mode_freq_mod(120, 10, 4000, 5678)
    print(gen.config)

    gen.set_continuous_mode_phase_mod(20000, 7, 5)
    print(gen.config)

    # serial = gen.serialize_config()

    msg = messages_pb2.Base_msg()
    msg.ParseFromString(serial)
    print(msg)

    gen.start()
    print(gen.control)

if __name__ == "__main__":
    # execute only if run as a script
    main()
