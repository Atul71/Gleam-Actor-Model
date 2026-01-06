# Gleam-Actor-Model
Consecutive Square sum computer (Gleam + Actor model) 
Consecutive Square sum computer (Gleam + Actor model) 
• The project is written in Gleam using the Actor model. 
• We are computing the sum of k consecutive squares and checking if its a perfect square. 
• We would return the value of the first element in the consecutive square if it is a perfect square. 
## Features 
• Setup done using a Supervisor/Boss-worker model. 
• Checks if the sum of k consecutive numbers is a perfect square? 
• Accepts command line input for dynamic numbers. 
• Modular designs with customer input -  SupervisorMessage, WorkerMessage, SupervisorState. 
## Dependencies – Add the following packages to run the program 
gleam add argv 
gleam add gleam_otp@1 
gleam add gleam_erlang@1 
##Usage 
Gleam run lukas <n> <k> 
The problems takes n and k as input in order to find k consecutive numbers starting at 1 or higher, and 
up to n, such that the sum of squares is itself a perfect square (of an integer) 

### Testing Equipment 
Laptop specifications : 
Processor: Intel(R) Core(TM) i5-9300H CPU @ 2.40GHz (8 CPUs), ~2.4GHz 

Size of work unit –  
Num of workers = use at most 1000 workers or n whichever is smaller 
The size of the work unit is chunk_size = n / Num of workers 
Each worker gets a range [start, stop] of size roughly chunk_size. 
Test Input – n = 1,000,000, k = 4 
 
 
## Code Structure 
 
The initial part of the code to add packages. 
 
The second part implements message types which defines how the supervisor and the worker talks to 
each other. The message types are Supervisor Message, Worker Message and Supervisor state. 
The third part implements function such as cpu_time_ms(), wall_time_ms(). This is to calculate the 
parallelism at the end of the program. 
The fourth part defines our Math helpers which are the main brain of computing. It checks the 
consecutive squares, sum of squares and finally if it is a perfect square. 
The fifth part determines the working nature of the worker and the supervisor. The functions are named 
handle_worker and handle_supervisor. 
The worker iterates k numbers from start to stop and checks if they are a perfect square. Once done it 
sends back the result to the supervisor, else sends the “Done” message to the supervisor for signal 
completion. The supervisor is assigned the task of processing the results. The main task is to print the 
results according to the message received from the worker, it also checks the states and the counts of 
the workers completed. 
The spawn worker function takes care of spawning the worker. 
The sixth part is the main brain of the code. This is the main() function. The initial setup in the main() 
function is to parse the input. The next major part is the assigning of the number of workers the 
supervisor need to have according the input given. The maximum number of workers the program will 
have is 1000. Then the supervisor is started followed by spawning of workers according to the input. 
Hence once the processing is done, the result is printed accordingly. Along with the result the 
parallelism of the program is also printed which is calculated by the formula CPU Time / Real time. 

## How it works? 
As the input is given in the format lukas <n> <k>, the boss/supervisor worker is called. Once the 
supervisor is called, spawn worker function is called and thereby the input is split into ranges according 
to the number of workers and each range is allotted to each worker. Worker computes the consecutive 
squares and checks the result value is a perfect square or not. Result is sent, the boss appends the result 
to the list maintained. The boss also maintains a done counter, which is incremented each time a done 
message is received. Once the done counter equals the number of workers, boss understands that all the 
workers are done, the result is printed and thereby the boss ceases its existence.
