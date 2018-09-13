import time

from cpython.exc cimport PyErr_CheckSignals


def thread_wait():
    """
    Wait for a short amount of time before executing anymore
    code on the thread, this reduces overall idle CPU usage...
    """

    # check for Python error signals so we can except
    # errors like KeyboardInterrupt, SystemExit etc...
    PyErr_CheckSignals()

    # hault the current thread for a short amount of time,
    # so that we use less CPU usage when idling to free up the
    # CPU for other running processes...
    time.sleep(0.0001)
