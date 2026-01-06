//////////////////////////////

//Import necessary modules
import argv
import gleam/erlang/atom
import gleam/erlang/process

//import gleam/float import only when using square_root function
import gleam/int
import gleam/io
import gleam/list
import gleam/otp/actor
import gleam/string

// Message Definiitions

pub type SupervisorMessage {
  Done

  Result(Int)
}

pub type WorkerMessage {
  Work(Int, Int, Int)
  //used to do the computation
}

//Create a state to track completed workers by boss actor
pub type SupervisorState {
  SupervisorState(completed_workers: Int, results: List(Int))
}

//Use erlang components for checking cpu time/schedulers/real time
@external(erlang, "erlang", "system_info")
pub fn system_info(which: atom.Atom) -> Int

@external(erlang, "erlang", "statistics")
pub fn statistics(which: atom.Atom) -> #(Int, Int)

fn cpu_time() -> Int {
  let #(time, _) = statistics(atom.create("runtime"))
  time
}

fn wall_time() -> Int {
  let #(time, _) = statistics(atom.create("wall_clock"))
  time
}

// Check if sum of k consecutive squares starting at s is a perfect square
fn check_consecutive_squares(s: Int, k: Int) -> Bool {
  // Sum of squares formula: n(n+1)(2n+1)/6

  let end = s + k - 1
  let sum_squares = sum_of_squares(end) - sum_of_squares(s - 1)

  is_perfect_square(sum_squares)
}

// Sum of squares from 1 to n
fn sum_of_squares(n: Int) -> Int {
  n * { n + 1 } * { 2 * n + 1 } / 6
}

// pub fn is_perfect_square(n: Int) -> Bool {
//   let assert Ok(n_sqsrt) = int.square_root(n)
//   let floored = float.floor(n_sqsrt)
//   floored *. floored == int.to_float(n)
// }

// Check if a number is a perfect square using binary search cause the float.floor is approximating and giving incorrect results for very higher order number with 0.9999999999999

pub fn is_perfect_square(n: Int) -> Bool {
  case n < 0 {
    True -> False
    False -> check_sqrt(1, n, n)
  }
}

fn check_sqrt(low: Int, high: Int, n: Int) -> Bool {
  case low > high {
    True -> False
    False -> {
      let mid = { low + high } / 2
      let mid_sq = mid * mid
      case mid_sq == n {
        True -> True
        False ->
          case mid_sq < n {
            True -> check_sqrt(mid + 1, high, n)
            False -> check_sqrt(low, mid - 1, n)
          }
      }
    }
  }
}

//Worker Handle Function
pub fn handle_worker(supervisor, message: WorkerMessage) {
  case message {
    Work(start, stop, k) -> {
      list.each(list.range(start, stop), fn(s) {
        case check_consecutive_squares(s, k) {
          True -> {
            // io.println("True that" <> int.to_string(s))

            actor.send(supervisor, Result(s))
          }
          False -> {
            Nil
            //  io.println("its false but im printing it " <> int.to_string(s))
          }
        }
      })
      actor.send(supervisor, Done)
      actor.continue(supervisor)
    }
  }
}

//Supervisor
pub fn handle_supervisor(
  state: SupervisorState,
  message: SupervisorMessage,
  total_workers: Int,
) {
  case message {
    Result(s) -> {
      io.println("Found - " <> int.to_string(s))
      let new_results = [s, ..state.results]
      let new_state =
        SupervisorState(
          completed_workers: state.completed_workers,
          results: new_results,
        )
      actor.continue(new_state)
    }

    Done -> {
      let new_completed = state.completed_workers + 1
      case new_completed == total_workers {
        True -> {
          io.println("All workers completed")
          let result_string =
            "["
            <> string.join(list.map(state.results, int.to_string), ", ")
            <> "]"
          io.println("Results: " <> result_string)
          actor.stop()
        }
        False -> {
          let new_state =
            SupervisorState(
              completed_workers: new_completed,
              results: state.results,
            )
          actor.continue(new_state)
        }
      }
    }
  }
}

//Spawn Workers as per range given in the code
pub fn spawn_workers(
  supervisor_subject,
  n: Int,
  k: Int,
  num_workers: Int,
) -> Int {
  let chunk_size = n / num_workers

  list.each(list.range(0, num_workers - 1), fn(i) {
    let start = i * chunk_size + 1
    let stop = case i == num_workers - 1 {
      True -> n
      False -> { i + 1 } * chunk_size
    }

    let assert Ok(worker) =
      actor.new(supervisor_subject)
      |> actor.on_message(handle_worker)
      |> actor.start

    actor.send(worker.data, Work(start, stop, k))
  })

  num_workers
}

pub type Event {
  Dones
}

// Main
// -----------------------
pub fn main() {
  case argv.load().arguments {
    [command, n_str, k_str] -> {
      case command {
        "lukas" -> {
          let n = case int.parse(n_str) {
            Ok(v) -> v
            Error(_) -> 0
          }
          let k = case int.parse(k_str) {
            Ok(v) -> v
            Error(_) -> 0
          }

          let start_real_time = wall_time()
          let start_cpu_time = cpu_time()

          let num_workers = case n {
            0 -> 1
            _ -> int.min(n, 1000)
            // use at most 1000 workers or n 
          }

          io.println("n: " <> int.to_string(n))
          io.println("k: " <> int.to_string(k))

          //Check schedulers
          let schedulers = system_info(atom.create("schedulers"))
          let schedulers_online = system_info(atom.create("schedulers_online"))

          let initial_state = SupervisorState(completed_workers: 0, results: [])
          // Start supervisor/boss actor
          let assert Ok(supervisor_actor) =
            actor.new(initial_state)
            |> actor.on_message(fn(initial_state, msg) {
              handle_supervisor(initial_state, msg, num_workers)
            })
            |> actor.start

          // Get the subject for sending messages
          let supervisor_subject = supervisor_actor.data
          let monitor = process.monitor(supervisor_actor.pid)

          let selector =
            process.new_selector()
            |> process.select_specific_monitor(monitor, fn(down) {
              io.println("---Program Execution Completed---")
              Dones
            })
          //spawn the workers from supervisor actor
          spawn_workers(supervisor_subject, n, k, num_workers)
          let _result = process.selector_receive(selector, within: 60_000)
          //  echo result

          let end_real_time = wall_time()
          let end_cpu_time = cpu_time()

          let real = end_real_time - start_real_time
          let cpu = end_cpu_time - start_cpu_time

          io.println("REAL TIME - " <> int.to_string(real))
          io.println("CPU TIME - " <> int.to_string(cpu))
          let parallelism = int.to_string(cpu / real)
          io.println("Parallelism - " <> parallelism)
          io.println("Schedulers configured: " <> int.to_string(schedulers))
          io.println("Schedulers online: " <> int.to_string(schedulers_online))

          Nil
        }
        _ -> {
          io.println("Usage to run: gleam run lukas <n> <k>")
          Nil
        }
      }
    }
    _ -> {
      io.println("Usage to run: gleam run lukas <n> <k>")
      Nil
    }
  }
}
