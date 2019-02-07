"""
======
mccore
======
"""

from libc.math cimport exp
from .energies cimport Energy
from .modifier cimport BaseModifier
from .random cimport random
cimport cython

cdef class Target:
    """Class to hold an Energy object with it associated neighbors"""
    cdef readonly int number_of_neighbors
    cdef readonly Py_ssize_t[:,:] neighbors
    cdef public Energy energy
    def __init__(self, Py_ssize_t[:,:] neighbors, Energy energy):
        assert neighbors.shape[1] == 5
        self.energy = energy
        self.neighbors = neighbors
        self.number_of_neighbors = len(self.neighbors)
    def __str__(self):
        return "{}(number_of_neighbors={})".format(self.__class__.__name__,self.number_of_neighbors)

@cython.cdivision(True)
@cython.boundscheck(False)
@cython.wraparound(False)
@cython.initializedcheck(False)
cpdef (int, int, int) mcrun(BaseModifier modifier, Target[:] targets,
                    int iterations, double temperature,
                    long[:,:,:,::1] a, double[:,:,:,::1] x, double[:,:,:,::1] y, double[:,:,:,::1] z):
    """This function is not meant to be used directly. It is used by
    :obj:`javelin.mc.MC`. The function does very little validation
    of the input values, it you don't provide exactly what is expected
    then segmentation fault is likely."""
    assert tuple(a.shape) == tuple(x.shape)
    assert tuple(a.shape) == tuple(y.shape)
    assert tuple(a.shape) == tuple(z.shape)
    cdef Py_ssize_t mod_x, mod_y, mod_z
    cdef int number_of_targets, number_of_cells
    cdef int accepted_good = 0
    cdef int accepted_neutral = 0
    cdef int accepted_bad = 0
    cdef Py_ssize_t cell_x_target, cell_y_target, cell_z_target, ncell
    cdef Py_ssize_t[:, :] cells
    cdef Py_ssize_t target_number, neighbour, number_of_neighbors
    cdef double e0, e1, de
    cdef Energy energy
    cdef Target target
    cdef Py_ssize_t[:,:] neighbors
    number_of_targets = targets.shape[0]
    number_of_cells = modifier.number_of_cells
    mod_x = a.shape[0]
    mod_y = a.shape[1]
    mod_z = a.shape[2]
    for _ in range(iterations):
        cells = modifier.get_random_cells(a.shape[0], a.shape[1], a.shape[2])
        e0 = 0
        for target_number in range(number_of_targets):
            target = targets[target_number]
            neighbors = target.neighbors
            energy = target.energy
            number_of_neighbors = target.number_of_neighbors
            for ncell in range(number_of_cells):
                for neighbour in range(number_of_neighbors):
                    if neighbors[neighbour,0] != cells[ncell, 3]:
                        continue
                    cell_x_target = (cells[ncell,0]+neighbors[neighbour,2]) % mod_x
                    cell_y_target = (cells[ncell,1]+neighbors[neighbour,3]) % mod_y
                    cell_z_target = (cells[ncell,2]+neighbors[neighbour,4]) % mod_z
                    e0 += energy.evaluate(a[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          x[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          y[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          z[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          a[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          x[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          y[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          z[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          neighbors[neighbour,2], neighbors[neighbour,3], neighbors[neighbour,4])
        modifier.run(a, x, y, z)
        e1 = 0
        for target_number in range(number_of_targets):
            target = targets[target_number]
            neighbors = target.neighbors
            energy = target.energy
            number_of_neighbors = target.number_of_neighbors
            for ncell in range(number_of_cells):
                for neighbour in range(number_of_neighbors):
                    if neighbors[neighbour,0] != cells[ncell, 3]:
                        continue
                    cell_x_target = (cells[ncell,0]+neighbors[neighbour,2]) % mod_x
                    cell_y_target = (cells[ncell,1]+neighbors[neighbour,3]) % mod_y
                    cell_z_target = (cells[ncell,2]+neighbors[neighbour,4]) % mod_z
                    e1 += energy.evaluate(a[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          x[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          y[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          z[cells[ncell,0], cells[ncell,1], cells[ncell,2], neighbors[neighbour,0]],
                                          a[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          x[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          y[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          z[cell_x_target, cell_y_target, cell_z_target, neighbors[neighbour,1]],
                                          neighbors[neighbour,2], neighbors[neighbour,3], neighbors[neighbour,4])
        de = e1-e0
        if accept(de, temperature):
            if de < 0:
                accepted_good += 1
            elif de == 0:
                accepted_neutral += 1
            else:
                accepted_bad += 1
        else:
            modifier.undo_last_run(a, x, y, z)

    return accepted_good, accepted_neutral, accepted_bad

@cython.cdivision(True)
cdef unsigned char accept(double dE, double kT):
    cdef double tmp
    if dE < 0:
        return True
    elif kT <= 0:
        return False
    else:
        return random() < exp(-dE/kT)
