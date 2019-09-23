### StateServer Versions

## 0.1

- first implementation
- compatibility with gen_statem style function outputs
- completion of documentation.

### 0.1.1

- actually push latest to master.
- minor documentation touchup
- enable documentation code links
- add licensing document

### 0.1.2

- fix bug where it fails to compile when it's a mix dependency

### 0.1.3

- fix child_spec/2 bug

### 0.1.4

- implementation of timeout on startup
- implemented transition cancellation
- made guards optional callbacks
- other cosmetic changes

## 0.2

- organization of function definitions by state

### Unscheduled

- better compatibility with gen_statem modules by providing `handle_event/3`
- implementation of timeout cancellation