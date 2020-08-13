from generator import Generator
import messages_pb2

def plot(gen):
    gen.start()
    gen.trigger_debug()
    gen.plot_samples()

def tests(gen):
    while True:
        try:
            gen.set_pulsed_mode_phase_mod(250,70,100,7)
            plot(gen)

            gen.set_continuous_mode_constant_freq(10)
            plot(gen)

            gen.set_continuous_mode_freq_mod(0, 500, 250)
            plot(gen)

            gen.set_pulsed_mode_constant_freq(250,100,500)
            plot(gen)

            gen.set_pulsed_mode_freq_mod(250,50,0,5000)
            plot(gen)

            gen.set_pulsed_mode_phase_mod(250,70,100,7)
            plot(gen)    

            gen.set_continuous_mode_constant_freq(21000)

        except Exception as e:
            print(e)
            pass

try:
    gen = Generator('192.168.1.10', 7)
    tests(gen)
    print("Test END")

except Exception as e:
    print(e)
